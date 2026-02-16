# Pivot Ideas — 100% Real, Zero Mocks

## ChatGPT's Top Pick: Bitcoin Reputation + Credit Primitive (#1 + #4 hybrid)
1. **Bitcoin-Backed Onchain Reputation** — Prove BTC holdings → mint Starknet soulbound credential (Whale/Diamond Hands/OG tiers)
2. **Ordinals → Starknet DeFi Unlocker** — Lock Ordinal → mint Starknet access token
3. **Bitcoin Time-Locked Vault** — BTC CLTV scripts + Starknet control layer = programmable savings bonds
4. **Bitcoin Credit Scoring** — Analyze BTC activity → mint onchain credit score NFT
5. **Ordinals Auction House** — Bid on Starknet, settle on Bitcoin

## Grok's Top Pick: Ordinal Auction House (#1)
1. **Ordinal Auction House** — English auction for live Bitcoin Ordinals, settled/escrowed on Starknet. PSBT signing via Xverse.
2. **Inscribe-to-Mint** — Inscribe on Bitcoin → claim tradable Starknet NFT (verified on-chain)
3. **RuneHolder DAO** — On-chain governance for any Bitcoin Rune, executed on Starknet. ECDSA sig verify in Cairo.
4. **Rare Sats Badge + Collector Registry** — Proof-of-ownership for rare sats, mintable as Starknet badges

## Convergence Analysis

Both recommend **Ordinal Auction House** highly. ChatGPT's #1 pick is **Reputation/Credit** (fastest to ship).

### Best candidates for 10-day solo build:

| Idea | Cairo Complexity | Xverse API Usage | Ship Time | Wow Factor |
|------|-----------------|-------------------|-----------|------------|
| Ordinal Auction House | Medium | Very High | 8-10 days | Highest |
| Inscribe-to-Mint | Low | High | 6-7 days | Very High |
| BTC Reputation/Credit | Low | Very High | 5-6 days | High |
| Rare Sats Badges | Low | Very High | 5-6 days | High |
| RuneHolder DAO | Medium | High | 7-8 days | High |

### Key Insight from Grok:
- `alexandria_btc` Scarb package exists for secp256k1 ECDSA verification in Cairo
- Xverse has workshop videos on sats-connect + Ordinals API
- Signet/Testnet4 works for real BTC testing
- No bridges, no oracles, no external indexers needed
