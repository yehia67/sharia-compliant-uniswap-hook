# Sharia-Compliant Hook for Uniswap v4

## Introduction

The Sharia-Compliant Hook for Uniswap v4 is a pioneering solution that bridges the gap between decentralized finance (DeFi) and Islamic finance principles. This project enables Muslim users to participate in DeFi activities while adhering to Sharia law, which prohibits interest (riba), excessive uncertainty (gharar), and gambling (maysir).

Key benefits of this project include:

- **Sharia Compliance**: All token interactions are vetted by a decentralized governance system with Islamic scholars (Muftis)
- **Transparency**: Open governance process for token whitelisting with clear documentation requirements
- **Reputation-Based Governance**: Decisions are weighted by the reputation of participants, ensuring quality control
- **Seamless Integration**: Built as a Uniswap v4 hook, allowing easy integration with the largest decentralized exchange ecosystem

## Architecture Overview

The system consists of three main components that work together to create a Sharia-compliant DeFi experience:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   ShariaHook    │◄────┤    ShariaDAO    │◄────┤ ShariaWhitelist │
│                 │     │                 │     │                 │
│ Uniswap v4 Hook │     │ Governance Body │     │ Token Registry │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        ▲                       ▲                       ▲
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│      Users      │     │     Muftis      │     │  Token Issuers  │
│                 │     │                 │     │                 │
│  Traders/LPs    │     │Islamic Scholars │     │  Project Teams  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### User Flow Sequence

1. **Token Whitelisting Process**:
   ```
   Token Issuer → ShariaDAO (Proposal) → Muftis (Voting) → ShariaWhitelist (Registry)
   ```

2. **Trading Process**:
   ```
   User → ShariaHook (Verification) → Uniswap v4 Pool (Execution)
   ```

## Smart Contracts

### 1. ShariaHook.sol

A Uniswap v4 hook that enforces Sharia compliance by:
- Only allowing interactions with whitelisted tokens
- Rewarding users with points for providing liquidity and trading
- Implementing the BaseHook and ERC20 interfaces
- Monitoring transactions via afterSwap and afterAddLiquidity hooks

### 2. ShariaDAO.sol

A decentralized autonomous organization (DAO) that governs the whitelisting process:
- Manages Mufti roles (Islamic scholars who verify compliance)
- Handles token proposals with compliance documentation
- Implements reputation-based voting system
- Executes successful proposals by updating the whitelist

### 3. ShariaWhitelist.sol

A registry of Sharia-compliant tokens:
- Maintains a list of verified tokens with metadata
- Provides verification functions for the hook
- Allows emergency removal of tokens if compliance issues arise
- Stores compliance documentation references

## Installation and Usage

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Setup

```shell
# Clone the repository
git clone https://github.com/yourusername/sharia-complient-hook.git
cd sharia-complient-hook

# Install dependencies
forge install
```

### Build

```shell
forge build
```

### Test

Run all tests:
```shell
forge test
```

Run specific test files:
```shell
forge test --match-path test/ShariaHook.t.sol
forge test --match-path test/ShariaDAO.t.sol
forge test --match-path test/ShariaWhitelist.t.sol
```

### Deploy

```shell
# Deploy to a local Anvil instance
anvil

# In a separate terminal
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast
```

## How to Contribute

1. **Fork the Repository**
   - Click the 'Fork' button at the top right of this repository

2. **Clone Your Fork**
   ```shell
   git clone https://github.com/yourusername/sharia-complient-hook.git
   cd sharia-complient-hook
   ```

3. **Create a Branch**
   ```shell
   git checkout -b feature/your-feature-name
   ```

4. **Make Your Changes**
   - Implement your feature or fix
   - Add tests for your changes
   - Ensure all tests pass with `forge test`

5. **Commit Your Changes**
   ```shell
   git commit -m "Add feature: your feature description"
   ```

6. **Push to Your Fork**
   ```shell
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Go to your fork on GitHub
   - Click 'New Pull Request'
   - Select your branch and submit the PR with a detailed description

## Real-Life Example

### Scenario: Islamic Investment Fund

An Islamic investment fund wants to offer its clients exposure to DeFi while ensuring Sharia compliance. Here's how they would use this system:

1. **Fund Setup**:
   - The fund's Sharia board (Muftis) join the ShariaDAO
   - They propose and vote on tokens that meet Islamic finance principles

2. **Client Investment**:
   - Clients deposit funds into the investment pool
   - The fund uses ShariaHook to provide liquidity only to whitelisted token pairs
   - Clients earn halal returns from trading fees and liquidity provision

3. **Ongoing Compliance**:
   - The Sharia board regularly reviews tokens for continued compliance
   - If a token no longer meets requirements, it can be removed from the whitelist
   - The fund automatically adjusts its positions based on the updated whitelist

This system enables the fund to offer Sharia-compliant DeFi exposure with transparent governance and automated compliance enforcement.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
