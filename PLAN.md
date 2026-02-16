# BTC Yield Vault — RE{DEFINE} Hackathon Plan

## Concept
One-click BTC → Starknet yield vault. Connect Xverse wallet, swap BTC to WBTC on Starknet, auto-deposit into yield strategies (Endur LSTs, Vesu lending), compound returns. Clean Bitcoin-native UX.

## Name Ideas
- **BTCVault** / **SatoshiVault** / **BitYield** / **StackSats** / **YieldBTC**

## Architecture
```
[Xverse Wallet] → [BTC → WBTC swap via Xverse API] → [Vault Contract (Cairo)]
                                                            ↓
                                                   [Strategy: Endur xWBTC staking]
                                                   [Strategy: Vesu WBTC lending]
                                                   [Strategy: Ekubo WBTC-USDC LP]
                                                            ↓
                                                   [Yield accrual → auto-compound]
                                                            ↓
                                                   [Withdraw: vault shares → WBTC → BTC]
```

## Stack
- **Smart contracts**: Cairo 2.15 + Scarb + Starknet Foundry
- **Frontend**: Next.js + starknet.js + Xverse wallet connector
- **Deployment**: Starknet testnet (Sepolia) → mainnet if time permits
- **APIs**: Xverse API (swap/bridge), Pragma (price oracle)

## Contract Design
1. **Vault.cairo** — ERC-4626-style vault (deposit WBTC → get vault shares)
2. **Strategy.cairo** — pluggable yield strategies (Endur staking, Vesu lending)
3. **Router.cairo** — auto-compound + rebalance across strategies

## Key Features
- [ ] Xverse wallet connect + BTC → WBTC swap flow
- [ ] Vault deposit/withdraw with share accounting
- [ ] At least 2 yield strategies (Endur + Vesu)
- [ ] Auto-compound mechanism
- [ ] Dashboard showing APY, TVL, user position
- [ ] Privacy angle: ZK proof of position without revealing amount (bonus)

## Timeline (12 days: Feb 17–28)
- **Day 1-2 (Feb 17-18)**: Cairo setup, vault contract skeleton, learn Endur/Vesu interfaces
- **Day 3-4 (Feb 19-20)**: Vault contract complete, strategy contracts, tests
- **Day 5-6 (Feb 21-22)**: Frontend scaffold, Xverse wallet integration
- **Day 7-8 (Feb 23-24)**: Xverse API swap flow, deposit/withdraw UI
- **Day 9-10 (Feb 25-26)**: Dashboard, auto-compound, testnet deploy
- **Day 11 (Feb 27)**: Polish, demo video recording
- **Day 12 (Feb 28)**: Submit on DoraHacks

## Submission Requirements
- [x] GitHub repo (public)
- [ ] Working demo on Starknet testnet/mainnet
- [ ] 3-minute demo video
- [ ] Project description (max 500 words)
- [ ] Starknet wallet address

## Why This Wins
1. **Xverse sponsor prize** — deep API integration = eligible for $5.5K in-kind
2. **Real composability** — builds on Endur/Vesu/Ekubo (not reinventing)
3. **Bitcoin-native UX** — Bitcoiners don't want to learn DeFi, just "deposit BTC, earn yield"
4. **BTCFi Season alignment** — leverages the 100M STRK incentive program
5. **Clean, shippable** — vault pattern is proven, reduces risk
