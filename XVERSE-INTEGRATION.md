# Xverse Integration Plan — SatStack

## Key Discovery: Sats Connect Natively Supports Starknet!

**`sats-connect`** (npm, 2M+ downloads) by Secret Key Labs (Xverse team) supports:
- Bitcoin L1 (PSBTs, transfers, Ordinals, Runes, BRC-20)
- Stacks
- Spark
- **Starknet** (addresses, transfers, contract calls)

This means Xverse wallet users can **sign Starknet transactions directly** from the Bitcoin wallet. No Argent/Braavos needed.

## Architecture: BTC-Native UX

```
User (Xverse Wallet)
    │
    ├── Bitcoin side: Send BTC
    │   └── Xverse Cross-chain Swap API (via Changelly)
    │       └── BTC → WBTC on Starknet
    │
    └── Starknet side: Sign vault deposit
        └── sats-connect: starknet contract calls
            └── SatStack Vault.deposit(wbtc_amount)
                ├── → Endur xWBTC (staking)
                └── → Vesu V2 (lending)
```

## Two Integration Layers

### 1. Sats Connect (Wallet Connection + Signing)
- `npm i sats-connect@4.2.x`
- `request('getAccounts', { purposes: [AddressPurpose.Payment, AddressPurpose.Starknet] })`
- Get both BTC address AND Starknet address from same wallet
- Sign Starknet vault deposit/withdraw txs via Xverse

### 2. Xverse Swap API (Cross-Chain BTC → WBTC)
- Base URL: `https://api.secretkeylabs.io`
- Requires API key (free trial via Typeform)
- **GET quotes**: `POST /v1/swaps/get-quotes` — get rates for BTC → WBTC
- **Cross-chain order**: `POST /v1/swaps/crosschain/place-order` — place BTC→WBTC swap via Changelly
  ```json
  {
    "from": { "protocol": "btc", "ticker": "btc" },
    "to": { "protocol": "starknet", "ticker": "wbtc" },
    "sendAmount": "0.001",
    "receiveAddress": "0x...(starknet address)",
    "providerCode": "changelly",
    "fromAddress": "bc1q..."
  }
  ```

## The "One-Click" Flow

1. User clicks "Deposit BTC" on SatStack
2. Frontend calls `sats-connect` → gets BTC + Starknet addresses
3. Frontend calls Xverse Swap API → gets quote for BTC → WBTC on Starknet
4. User confirms in Xverse wallet (signs BTC PSBT to send BTC)
5. Changelly bridges BTC → WBTC arrives on user's Starknet address
6. Frontend detects WBTC arrival → prompts vault deposit
7. User signs Starknet tx via `sats-connect` → WBTC deposited into SatStack vault
8. Dashboard shows: "Your BTC is earning X% APY" (denominated in sats)

## Key Differentiator

**User never installs Argent/Braavos.** The entire flow happens through Xverse — their Bitcoin wallet. They think in BTC, see results in sats, and the Starknet plumbing is invisible.

## API Key

Need to apply: https://form.typeform.com/to/HkwDUt9P
- Mention we're building for RE{DEFINE} hackathon
- Bitcoin track, using their swap + crosschain APIs

## Frontend Changes Needed

1. Replace `@starknet-react/core` wallet connect with `sats-connect`
2. Use `AddressPurpose.Starknet` to get Starknet address
3. Build BTC deposit flow using cross-chain swap API
4. Keep Starknet contract calls via sats-connect
5. Show all values in BTC/sats denomination
6. Add yield tracking: "X sats earned today"

## Docs References
- Sats Connect: https://docs.xverse.app/sats-connect
- Xverse API: https://docs.xverse.app/api
- GitHub: https://github.com/secretkeylabs/sats-connect
- Example App: https://sats-connect.netlify.app/
- Next.js guide: https://docs.xverse.app/sats-connect/guides/next.js-support
