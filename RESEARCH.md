# RE{DEFINE} Starknet Hackathon — Bitcoin Track Research

## Key Intel (from Grok, Feb 16 2026)

### Starknet BTC DeFi Landscape
- **Dual-staked rollup** (SNIP-31, live Oct 2025) — wrapped BTC contributes up to 25% of consensus power
- **BTCFi Season**: 100M STRK incentives (~$10-13M) subsidizing liquidity/lending/LP
- BTC TVL was ~$16M at launch, grown with incentives
- Yields: staking 5-12% APY, lending 3-8%, LP 5-15%, vaults 8-15%

### BTC Wrappers on Starknet
- **WBTC** (canonical, bridged from Ethereum or via Atomiq/Garden)
- **tBTC** (Threshold Network — decentralized 1:1 BTC)
- **LBTC** (Lombard — Babylon-staked BTC, liquid, multichain)
- **SolvBTC** (Solv Protocol — yield-bearing BTC wrapper)
- No native sBTC (that's Stacks)

### Bridges/Onramps
- **Atomiq** — trust-minimized atomic swaps BTC ↔ WBTC (no custodians)
- **Garden Finance** — P2P Bitcoin bridge
- **LayerSwap, Rhino.fi, StarkGate** (ETH → Starknet)
- **LayerZero/Hyperlane** (cross-chain, 140+ chains)
- **Xverse wallet** — native one-click BTC → Starknet WBTC

### Key Protocols
- **Lending**: Vesu (permissionless, V2 for BTCFi), Uncap (BTC-backed USDU), Opus, Nostra, Extended
- **DEXes**: Ekubo (concentrated liquidity), AVNU (aggregator), JediSwap, LayerAkira
- **Staking/Vaults**: Endur (LSTs: xWBTC, xtBTC, xLBTC), Troves (yield aggregator), ForgeYields/Noon
- **Other**: Re7 Capital's mRe7BTC (~20% target yield), Pragma oracles, Broly (inscriptions)

### Xverse API
- Leading Bitcoin wallet (>1M users), deep native Starknet integration
- REST APIs: Bitcoin RPC/UTXO, Ordinals/Runes/BRC-20, swap aggregator, cross-chain bridging, portfolio
- Users can swap BTC → WBTC on Starknet directly in-wallet
- **Hackathon sponsor** — in-kind prizes ($5.5K for top 3 Xverse-using projects)

### Cairo/Tooling (Current)
- **Cairo ~2.15.0** (via latest Scarb)
- **Scarb**: Package manager + build tool. Install via `starkup` or `asdf`
- **Starknet Foundry** (`snforge`/`sncast`): Testing + deployment (requires Scarb ≥2.13)
- Setup: `curl -L https://raw.githubusercontent.com/software-mansion/starkup/main/starkup | sh`
- OpenZeppelin Cairo contracts via Scarb.toml
- Dev experience greatly improved in 2025

### Gaps/Opportunities (Solo Dev, 12 Days)
1. **Xverse-native yield dashboard/vault** — one-click BTC → LST → compound yields + privacy/ZK
2. **Custom Vesu market** — permissionless niche lending pool (LBTC-only, custom params)
3. **BTC-backed stable/structured product** — over-collateralized BTCUSD, auto-farms Vesu
4. **Runes/Ordinals DeFi hook** — Xverse API + Broly for marketplace/yield on Runes
5. **Privacy wrapper or perps lite** — Cairo ZK for private BTC positions
6. **Payment/settlement** — Bitcoin QR payments settling on Starknet

### Winning Playbook
- Composable with Vesu/Ekubo/Endur + Xverse onramp
- Emphasize sustainable yield, privacy/ZK, Bitcoin-native UX
- Demo with real BTC wrapper flow via Xverse
- Deploy to testnet/mainnet; use latest Cairo/Foundry
- Judges want: BTC-native UX + real composability + Cairo/ZK angle

## Hackathon Details
- **Deadline**: Feb 28, 23:59 UTC
- **Prizes**: $9,675 STRK + $5,500 in-kind (Xverse)
- **Requirements**: GitHub repo, 3-min demo video, 500-word description, deployed on testnet/mainnet, Starknet wallet address
- **Platform**: DoraHacks
- **Telegram**: https://t.me/+-5zNW47GSdQ1ZDkx
