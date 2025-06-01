// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DecentralizedMarketplace - Complete P2P Trading Platform
 * @dev Enables peer-to-peer trading with automated escrow, fee collection, and delivery confirmation
 * @author Idris Elgarrab, Abdennour Alouach
 * @notice Sellers list items, buyers purchase with ETH, platform takes configurable fees
 * @notice Features delivery confirmation system and secure earnings withdrawal
 */
contract DecentralizedMarketplace {
    
    // Platform administration and tracking
    address public owner;                    // Contract deployer who receives marketplace fees
    uint16 public marketplaceFeePercent;     // Platform commission (250 = 2.5%, max 10%)
    uint32 private itemCounter;              // Auto-incrementing unique ID for each listing
    
    // Complete item information stored efficiently in blockchain
    struct Item {
        uint32 id;                    // Unique identifier for this listing
        uint128 price;                // Sale price in wei (1 ETH = 10^18 wei)
        address seller;               // Who listed this item for sale
        
        address buyer;                // Who purchased this item (zero address if unsold)
        uint32 listedAt;              // When item was listed (Unix timestamp)
        bool isActive;                // Can this item still be purchased?
        bool isDelivered;             // Has buyer confirmed receipt of item?
        
        string name;                  // Display name of the item
        string description;           // Detailed description for buyers
    }
    
    // Data organization for efficient queries and user tracking
    mapping(uint32 => Item) public items;                    // All items by ID
    mapping(address => uint32[]) public sellerItems;         // Items each seller has listed
    mapping(address => uint32[]) public buyerPurchases;      // Items each buyer has purchased
    mapping(address => uint256) public sellerEarnings;       // ETH available for seller withdrawal
    
    // Blockchain events for frontend integration and transaction history
    event ItemListed(
        uint32 indexed itemId,        // Easy filtering by item
        string name,                  // What was listed
        uint128 price,                // At what price
        address indexed seller,       // Who listed it
        uint32 timestamp              // When it was listed
    );
    
    event ItemPurchased(
        uint32 indexed itemId,        // Which item was bought
        address indexed buyer,        // Who bought it
        address indexed seller,       // Who sold it
        uint128 price,                // Final sale price
        uint32 timestamp              // When sale completed
    );
    
    event ItemDelivered(
        uint32 indexed itemId,        // Which item was delivered
        address indexed buyer,        // Who confirmed delivery
        uint32 timestamp              // When delivery was confirmed
    );
    
    event EarningsWithdrawn(
        address indexed seller,       // Who withdrew earnings
        uint256 amount,               // How much ETH withdrawn
        uint32 timestamp              // When withdrawal occurred
    );
    
    event MarketplaceFeeUpdated(
        uint16 oldFee,                // Previous fee percentage
        uint16 newFee,                // New fee percentage
        uint32 timestamp              // When fee was changed
    );
    
    // Access control and validation modifiers for security
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier onlySeller(uint32 _itemId) {
        require(items[_itemId].seller == msg.sender, "Only seller");
        _;
    }
    
    modifier onlyBuyer(uint32 _itemId) {
        require(items[_itemId].buyer == msg.sender, "Only buyer");
        _;
    }
    
    modifier itemExists(uint32 _itemId) {
        require(_itemId > 0 && _itemId <= itemCounter, "Item not found");
        _;
    }
    
    modifier itemActive(uint32 _itemId) {
        require(items[_itemId].isActive, "Item inactive");
        _;
    }
    
    /**
     * @dev Initialize marketplace with platform fee structure
     * @param _initialFeePercent Platform commission in basis points (250 = 2.5%)
     * @notice Only values 0-1000 allowed (max 10% platform fee)
     */
    constructor(uint16 _initialFeePercent) {
        require(_initialFeePercent <= 1000, "Fee > 10%"); // Max 10% fee
        owner = msg.sender;
        marketplaceFeePercent = _initialFeePercent;
    }
    
    /**
     * @dev Create a new item listing for sale on the marketplace
     * @param _name Display name for the item (must not be empty)
     * @param _description Detailed information about the item condition, specs, etc.
     * @param _price Sale price in wei (1 ETH = 1000000000000000000 wei)
     * @notice Emits ItemListed event for frontend integration
     * @notice Item gets unique ID and is immediately available for purchase
     */
    function listItem(
        string calldata _name, // Use calldata instead of memory for gas savings
        string calldata _description,
        uint128 _price // Reduced from uint256 to uint128
    ) external {
        require(bytes(_name).length > 0, "Empty name");
        require(_price > 0, "Price = 0");
        
        // Generate unique ID for this listing
        unchecked { ++itemCounter; }
        
        // Record current time for listing history
        uint32 timestamp = uint32(block.timestamp);
        
        items[itemCounter] = Item({
            id: itemCounter,
            name: _name,
            description: _description,
            price: _price,
            seller: msg.sender,
            buyer: address(0),
            isActive: true,
            isDelivered: false,
            listedAt: timestamp
        });
        
        sellerItems[msg.sender].push(itemCounter);
        
        emit ItemListed(itemCounter, _name, _price, msg.sender, timestamp);
    }
    
    /**
     * @dev Execute purchase of an active item listing
     * @param _itemId Unique identifier of item to purchase
     * @notice Must send exact price amount in ETH with transaction
     * @notice Platform fee is automatically deducted and sent to owner
     * @notice Seller earnings are held in contract until withdrawal
     * @notice Emits ItemPurchased event with transaction details
     */
    function purchaseItem(uint32 _itemId) 
        external 
        payable 
        itemExists(_itemId) 
        itemActive(_itemId) 
    {
        Item storage item = items[_itemId];
        
        require(msg.sender != item.seller, "Self purchase");
        require(msg.value == uint256(item.price), "Wrong amount");
        
        // Calculate platform commission and seller net amount
        uint256 price = uint256(item.price);
        uint256 fee = (price * uint256(marketplaceFeePercent)) / 10000;
        uint256 sellerAmount = price - fee;
        
        // Mark item as sold and record buyer
        item.buyer = msg.sender;
        item.isActive = false;
        
        // Track this purchase for buyer's history
        buyerPurchases[msg.sender].push(_itemId);
        
        // Hold seller earnings for later withdrawal
        sellerEarnings[item.seller] += sellerAmount;
        
        // Send platform fee immediately to marketplace owner
        if (fee > 0) {
            payable(owner).transfer(fee);
        }
        
        emit ItemPurchased(_itemId, msg.sender, item.seller, item.price, uint32(block.timestamp));
    }
    
    /**
     * @dev Buyer confirms successful delivery of purchased item
     * @param _itemId ID of the purchased item to mark as delivered
     * @notice Only the buyer who purchased the item can confirm delivery
     * @notice Item must be purchased (not active) before delivery confirmation
     * @notice This creates permanent record of successful transaction completion
     */
    function confirmDelivery(uint32 _itemId) 
        external 
        itemExists(_itemId) 
        onlyBuyer(_itemId) 
    {
        Item storage item = items[_itemId];
        require(!item.isActive, "Not purchased");
        require(!item.isDelivered, "Already delivered");
        
        item.isDelivered = true;
        
        emit ItemDelivered(_itemId, msg.sender, uint32(block.timestamp));
    }
    
    /**
     * @dev Seller withdraws accumulated earnings from completed sales
     * @notice Transfers all available earnings to seller's wallet
     * @notice Earnings are net amount after platform fees have been deducted
     * @notice Uses withdrawal pattern to prevent reentrancy attacks
     * @notice Emits EarningsWithdrawn event for transaction tracking
     */
    function withdrawEarnings() external {
        uint256 earnings = sellerEarnings[msg.sender];
        require(earnings > 0, "No earnings");
        
        sellerEarnings[msg.sender] = 0; // Clear balance before transfer (prevents reentrancy)
        
        payable(msg.sender).transfer(earnings);
        
        emit EarningsWithdrawn(msg.sender, earnings, uint32(block.timestamp));
    }
    
    /**
     * @dev Platform owner adjusts marketplace commission rate
     * @param _newFeePercent New commission rate in basis points (250 = 2.5%)
     * @notice Only contract owner can modify fees
     * @notice Maximum allowed fee is 10% (1000 basis points)
     * @notice Fee changes apply to all future transactions
     */
    function updateMarketplaceFee(uint16 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 1000, "Fee > 10%");
        
        uint16 oldFee = marketplaceFeePercent;
        marketplaceFeePercent = _newFeePercent;
        
        emit MarketplaceFeeUpdated(oldFee, _newFeePercent, uint32(block.timestamp));
    }
    
    /**
     * @dev Seller removes their unsold item from marketplace
     * @param _itemId ID of the item to delist
     * @notice Only the original seller can remove their own items
     * @notice Can only remove items that haven't been purchased yet
     * @notice Item becomes inactive and unavailable for purchase
     */
    function removeItem(uint32 _itemId) 
        external 
        itemExists(_itemId) 
        onlySeller(_itemId) 
        itemActive(_itemId) 
    {
        items[_itemId].isActive = false;
    }
    
    // ============ VIEW FUNCTIONS - Read marketplace data ============
    
    /**
     * @dev Get total number of items ever listed on marketplace
     * @return Current item counter value
     */
    function getTotalItems() external view returns (uint32) {
        return itemCounter;
    }
    
    /**
     * @dev Retrieve complete information about a specific item
     * @param _itemId Unique identifier of the item
     * @notice Returns structured data for frontend display
     */
    function getItem(uint32 _itemId) 
        external 
        view 
        itemExists(_itemId) 
        returns (
            uint32 id,
            string memory name,
            string memory description,
            uint128 price,
            address seller,
            address buyer,
            bool isActive,
            bool isDelivered,
            uint32 listedAt
        ) 
    {
        Item storage item = items[_itemId]; // Direct storage access for efficiency
        return (
            item.id,
            item.name,
            item.description,
            item.price,
            item.seller,
            item.buyer,
            item.isActive,
            item.isDelivered,
            item.listedAt
        );
    }
    
    /**
     * @dev Get list of all item IDs that a seller has listed
     * @param _seller Address of the seller to query
     * @return Array of item IDs listed by this seller
     */
    function getSellerItems(address _seller) external view returns (uint32[] memory) {
        return sellerItems[_seller];
    }
    
    /**
     * @dev Get list of all item IDs that a buyer has purchased
     * @param _buyer Address of the buyer to query
     * @return Array of item IDs purchased by this buyer
     */
    function getBuyerPurchases(address _buyer) external view returns (uint32[] memory) {
        return buyerPurchases[_buyer];
    }
    
    /**
     * @dev Check how much ETH a seller can withdraw from completed sales
     * @param _seller Address of the seller to query
     * @return Amount of wei available for withdrawal
     */
    function getSellerEarnings(address _seller) external view returns (uint256) {
        return sellerEarnings[_seller];
    }
    
    /**
     * @dev Browse available items with pagination to manage gas usage
     * @param _start Starting index for pagination (0-based)
     * @param _limit Maximum number of items to return (1-100)
     * @return Array of active item IDs within the specified range
     * @notice Use for efficient browsing of large marketplaces
     */
    function getActiveItems(uint32 _start, uint32 _limit) 
        external 
        view 
        returns (uint32[] memory) 
    {
        require(_limit > 0 && _limit <= 100, "Invalid limit"); // Prevent excessive gas usage
        
        uint32[] memory activeItemIds = new uint32[](_limit);
        uint32 activeCount = 0;
        uint32 currentIndex = 0;
        
        for (uint32 i = 1; i <= itemCounter && activeCount < _limit; ) {
            if (items[i].isActive) {
                if (currentIndex >= _start) {
                    activeItemIds[activeCount] = i;
                    unchecked { ++activeCount; }
                }
                unchecked { ++currentIndex; }
            }
            unchecked { ++i; }
        }
        
        // Return only the filled portion of the array
        uint32[] memory result = new uint32[](activeCount);
        for (uint32 i = 0; i < activeCount; ) {
            result[i] = activeItemIds[i];
            unchecked { ++i; }
        }
        
        return result;
    }
    
    /**
     * @dev Get all currently available items for purchase
     * @return Array of all active item IDs
     * @notice For small marketplaces only - use getActiveItems(start, limit) for large datasets
     * @notice May hit gas limits if marketplace has many items
     */
    function getAllActiveItems() external view returns (uint32[] memory) {
        uint32[] memory activeItemIds = new uint32[](itemCounter);
        uint32 activeCount = 0;
        
        for (uint32 i = 1; i <= itemCounter; ) {
            if (items[i].isActive) {
                activeItemIds[activeCount] = i;
                unchecked { ++activeCount; }
            }
            unchecked { ++i; }
        }
        
        // Return properly sized array with only active items
        uint32[] memory result = new uint32[](activeCount);
        for (uint32 i = 0; i < activeCount; ) {
            result[i] = activeItemIds[i];
            unchecked { ++i; }
        }
        
        return result;
    }
    
    /**
     * @dev Platform owner emergency function to recover stuck funds
     * @notice Should only be used if contract has critical issues
     * @notice Transfers entire contract balance to owner
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Check total ETH balance held by the marketplace contract
     * @return Contract balance in wei
     * @notice Includes platform fees and seller earnings awaiting withdrawal
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}