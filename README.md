# 💰 Tip Jar with Daily Limits

A Clarity smart contract that implements a tip jar system with daily spending limits per user. Perfect for learning rate limiting concepts in blockchain development! 🚀

## ✨ Features

- 💸 **Send Tips**: Users can send STX tips to the contract
- 🔒 **Daily Limits**: Each user has a maximum tip amount per day (default: 1 STX)
- 📊 **Usage Tracking**: Track daily and total tips per user
- 👑 **Owner Controls**: Contract owner can withdraw funds and adjust settings
- ⏸️ **Emergency Controls**: Pause/resume contract functionality
- 📈 **Statistics**: View daily stats and user tip history

## 🎯 Core Concepts

This contract demonstrates:
- **Rate Limiting**: Users cannot exceed daily tip limits
- **Time-based Logic**: Uses block height to determine "days"
- **Access Control**: Owner-only functions for management
- **State Management**: Tracking multiple data points efficiently

## 🚀 Quick Start

### Deploy the Contract

```bash
clarinet deploy
```

### Basic Usage

#### Send a Tip 💝
```bash
clarinet console
(contract-call? .tip-jar-with-limits send-tip u500000)
```

#### Check Your Daily Limit 📊
```bash
(contract-call? .tip-jar-with-limits get-user-remaining-limit tx-sender)
```

#### View Contract Balance 💰
```bash
(contract-call? .tip-jar-with-limits get-contract-balance)
```

## 📋 Available Functions

### 👤 User Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `send-tip` | Send a tip to the jar | `amount: uint` |
| `get-user-daily-tips` | Check daily tips sent | `user: principal` |
| `get-user-remaining-limit` | Check remaining daily limit | `user: principal` |
| `get-tip-history-summary` | Get complete user stats | `user: principal` |
| `can-tip?` | Check if user can send amount | `user: principal, amount: uint` |

### 👑 Owner Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `withdraw-tips` | Withdraw specific amount | `amount: uint` |
| `withdraw-all-tips` | Withdraw entire balance | None |
| `set-daily-limit` | Update daily tip limit | `new-limit: uint` |
| `toggle-contract-status` | Pause/resume contract | None |
| `emergency-pause` | Emergency stop | None |

### 📊 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-contract-balance` | Current contract STX balance |
| `get-daily-limit` | Current daily tip limit |
| `get-total-tips` | Total tips received |
| `get-current-day-stats` | Today's tip statistics |
| `get-contract-status` | Contract active status |

## 🔧 Configuration

### Default Settings
- **Daily Limit**: 1,000,000 microSTX (1 STX)
- **Day Calculation**: Based on block height (144 blocks ≈ 1 day)
- **Contract Status**: Active by default

### Customize Daily Limit
```bash
(contract-call? .tip-jar-with-limits set-daily-limit u2000000)
```

## 💡 Example Scenarios

### Scenario 1: Regular Tipping 🎯
```bash
# Send 0.5 STX tip
(contract-call? .tip-jar-with-limits send-tip u500000)

# Check remaining limit
(contract-call? .tip-jar-with-limits get-user-remaining-limit tx-sender)
# Returns: u500000 (0.5 STX remaining)
```

### Scenario 2: Hit Daily Limit 🚫
```bash
# Try to send 1.5 STX when limit is 1 STX
(contract-call? .tip-jar-with-limits send-tip u1500000)
# Returns: (err u102) - Daily limit exceeded
```

### Scenario 3: Owner Management 👑
```bash
# Check contract balance
(contract-call? .tip-jar-with-limits get-contract-balance)

# Withdraw all tips
(contract-call? .tip-jar-with-limits withdraw-all-tips)
```

## 🛡️ Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner only function |
| `u101` | Insufficient amount |
| `u102` | Daily limit exceeded |
| `u103` | Invalid amount |
| `u104` | Withdrawal failed |
| `u105` | Tip transfer failed |

## 🧪 Testing

### Test Daily Limits
```bash
# Send maximum daily amount
(contract-call? .tip-jar-with-limits send-tip u1000000)

# Try to send more (should fail)
(contract-call? .tip-jar-with-limits send-tip u1)
```

### Test Owner Functions
```bash
# Pause contract
(contract-call? .tip-jar-with-limits emergency-pause)

# Try to tip (should fail)
(contract-call? .tip-jar-with-limits send-tip u100000)

# Resume contract
(contract-call? .tip-jar-with-limits resume-contract)
```

## 🎓 Learning Outcomes

After working with this contract, you'll understand:
- ✅ How to implement rate limiting in smart contracts
- ✅ Time-based logic using block heights
- ✅ Multi-dimensional data mapping
- ✅ Access control patterns
- ✅ Emergency stop mechanisms
- ✅ State management best practices

## 🤝 Contributing

Feel free to submit issues and enhancement requests! This is a learning project designed to demonstrate core blockchain concepts.

---

**Happy Tipping!** 🎉💰
```

**Git Commit Message:**
```
feat: implement tip jar with daily limits MVP
```

**GitHub Pull Request Title:**
```
🚀 Add Tip Jar with Daily Limits Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## 💰 Tip Jar with Daily Limits MVP

This PR introduces a complete Clarity smart contract that implements a tip jar system with daily spending limits per user.

### ✨ What's Added

- **Smart Contract**: Complete tip jar implementation with rate limiting
- **User Functions**: Send tips with daily limit enforcement
- **Owner Controls**: Withdraw funds, adjust limits, pause/resume contract
- **Statistics Tracking**: Daily and total tip tracking per user
- **Emergency Features**: Pause functionality for contract safety
- **Comprehensive README**: Full documentation with examples and usage instructions

### 🎯 Key Features

- Daily tip limits per user (default: 1 STX)
- Time-based logic using block heights
- Multi-dimensional data tracking
- Access control for owner functions
- Emergency stop mechanisms
- Complete error handling

### 📚 Learning Focus

This contract teaches essential blockchain concepts:
- Rate limiting implementation
- Time-based smart contract logic
- State management patterns
- Access control mechanisms

Ready for testing and deployment with Clarinet! 🚀

