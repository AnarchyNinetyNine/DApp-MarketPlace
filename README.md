# 🛒 Decentralized Marketplace (Ethereum Smart Contract)

> A complete peer-to-peer trading platform on Ethereum with automated escrow, delivery confirmation, fee collection, and seller withdrawal.

## 📜 Overview

**DecentralizedMarketplace** is a fully on-chain marketplace that enables sellers to list items and buyers to purchase them using ETH. With built-in escrow and a delivery confirmation mechanism, it ensures secure transactions and fair settlements. Marketplace owners earn configurable fees from every successful trade.

Built with Solidity `^0.8.19`.

## 👨‍💻 Authors

- Idris Elgarrab
- Abdennour Alouach

## ✨ Features

- ✅ Sellers list items for sale
- ✅ Buyers purchase using ETH
- ✅ Escrowed payments until delivery is confirmed
- ✅ Platform collects a commission fee
- ✅ Sellers can withdraw earnings securely
- ✅ Event-based design for easy frontend integration
- ✅ Fee configuration by the contract owner

## 🧱 Smart Contract Architecture

### 📦 Structs

- **Item**
  - `id`: Unique ID
  - `name`: Item name
  - `description`: Detailed description
  - `price`: Sale price (in wei)
  - `seller`: Address of the lister
  - `buyer`: Address of purchaser (if sold)
  - `listedAt`: Timestamp of listing
  - `isActive`: Whether it's still purchasable
  - `isDelivered`: Delivery confirmation status

### 🔐 Access Control

- `onlyOwner`: Restricts function to contract deployer
- `onlySeller`: Restricts function to original lister
- `onlyBuyer`: Restricts function to buyer of an item

### 💵 Fee System

- Fees are in basis points (e.g., `250 = 2.5%`)
- Max fee allowed: 10%
- Earnings are escrowed and withdrawn manually

## 🚀 Usage

### 🧪 Deployment

```bash
# Using Hardhat (example)
npx hardhat compile
npx hardhat run scripts/deploy.js --network <network>
```
## 📘 Sample Interactions

### List an item
```solidity
listItem("Gaming Mouse", "RGB Mouse, used for 6 months", 100000000000000000); // 0.1 ETH
```

### Purchase an item
```solidity
purchaseItem(1) // Must send exact ETH value
```

### Confirm delivery
```solidity
confirmDelivery(1)
```

### Withdraw earnings
```solidity
withdrawEarnings()
```

### Update fee (Owner only)
```solidity
updateMarketplaceFee(300) // 3% platform fee
```

### Remove an unsold item
```solidity
removeItem(1)
```

---

## 📡 Events

| Event                | Description                                |
|----------------------|--------------------------------------------|
| `ItemListed`         | Emitted when a seller lists an item        |
| `ItemPurchased`      | Emitted when an item is purchased          |
| `ItemDelivered`      | Emitted when buyer confirms delivery       |
| `EarningsWithdrawn`  | Emitted when seller withdraws earnings     |
| `MarketplaceFeeUpdated` | Emitted when owner updates the fee     |

---

## 🛠️ Developer Notes

- All monetary values are in **wei**
- Uses `uint128` for price to reduce gas usage
- `calldata` used for strings to optimize costs
- Non-reentrant pattern used for withdrawals
- Max platform fee capped at **10%**

---

## 🧪 Testing Suggestions

Write tests for:
- Listing and purchasing items
- Ensuring fee is correctly deducted
- Delivery confirmation process
- Earnings withdrawal with and without delivery
- Fee adjustment by the owner
- Unauthorized access attempts

---

## 📄 License

**MIT License**
