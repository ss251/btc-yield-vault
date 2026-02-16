# BTC DeFi Landscape on Starknet

*Research Date: Feb 16, 2026*

---

## 1. Endur Finance — Liquid Staking

**Website:** https://endur.fi | **Docs:** https://docs.endur.fi

### Supported BTC LSTs (Mainnet)

| Deposit Asset | LST Token | LST Contract |
|---|---|---|
| WBTC | xWBTC | `0x06a567e68...` |
| tBTC (Threshold) | xtBTC | `0x043a35c14...` |
| LBTC (Lombard) | xLBTC | `0x07dd3c80d...` |
| SolvBTC | xsBTC | `0x0580f3dc5...` |
| STRK | xSTRK | `0x028d709c8...` |

### How It Works Programmatically

- All LSTs follow **ERC-4626** standard (deposit/withdraw pattern)
- **Deposit:** Call `deposit(assets, receiver)` on the LST contract — supply underlying BTC variant, receive LST shares
- **Withdraw:** Unlike standard ERC-4626, withdrawals mint an **NFT** (ERC-721 from Withdraw Queue contract). The NFT is settled for underlying assets when funds are available. Settlement is automatic and permissionless — your contract must be able to receive tokens.
- **No fees** on stake or redemption
- Faster unstaking than native 7-day period

### Key Contracts (Mainnet)

| Contract | Address |
|---|---|
| xSTRK (ERC4626) | `0x28d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a` |
| Withdraw Queue (ERC721) | `0x518a66e579f9eb1603f5ffaeff95d3f013788e9c37ee94995555026b9648b6` |
| Validator Registry | `0x029edbca81c979decd6ee02205127e8b10c011bca1d337141170095eba690931` |

### Sepolia Testnet

- **xSTRK on Sepolia:** `0x042de5b868da876768213c48019b8d46cd484e66013ae3275f8a4b97b31fc7eb`
- **Withdraw Queue on Sepolia:** `0x254cbdaf8275cb1b514ae63ccedb04a3a9996b1489829e5d6bbaf759ac100b6`
- ⚠️ **BTC LSTs on Sepolia: "Work in progress"** — not yet deployed on testnet

### APY

- Endur advertises BTC APY and STRK APY on their homepage but the exact numbers are dynamically loaded (not extractable via static fetch). Check https://endur.fi for live rates. Expected to be boosted by BTCFi Season STRK incentives.

---

## 2. Vesu V2 — Lending Protocol

**Website:** https://vesu.xyz | **Docs:** https://docs.vesu.xyz | **GitHub:** https://github.com/vesuxyz/vesu-v2

### Architecture

- **Isolated pools** — each pool is a separate `Pool` contract instance (funds isolation by design)
- **No hooks/extensions** (simplified from V1)
- **vTokens** — stand-alone **ERC-4626** vaults deployed per asset per pool
- **Oracle:** Factory Oracle using Pragma price feeds with validation
- **PoolFactory** deploys pools + vTokens in one step
- Permissionless pool creation and curation
- Hypernative real-time threat detection (opt-in)

### Key Contracts (Mainnet)

| Contract | Address |
|---|---|
| PoolFactory | `0x3760f903a37948f97302736f89ce30290e45f441559325026842b7a6fb388c0` |
| Default Pool | `0x451fe483d5921a2919ddd81d0de6696669bccdacd859f72a4fba7656b97c3b5` |
| Oracle | `0xfe4bfb1b353ba51eb34dff963017f94af5a5cf8bdf3dfc191c504657f3c05` |
| Pausing Agent | `0x773daa9f2605288be0e7586fa8390b7a9f9c4016dc36f68c7effa48de125583` |

### How to Supply/Withdraw Programmatically

**Option A: vToken (ERC-4626) — Recommended**

```cairo
// Supply: approve asset, then call deposit on the vToken
fn deposit(assets: u256, receiver: ContractAddress) -> u256  // returns shares minted

// Withdraw:
fn withdraw(assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256  // returns shares burned
```

**Option B: Pool.manage_position (direct)**

```
ModifyPositionParams {
    collateral_asset: <asset_address>,
    debt_asset: <any_supported_asset_in_pool>,  // implementation detail
    user: <position_owner>,
    collateral: Amount { value: <positive_to_supply, negative_to_withdraw> },
    debt: Amount { value: 0 }
}
```

- If `user != sender`, user must first call `modify_delegation` to delegate

### Known Assets in Default Pool

- ETH: `0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7`
- wstETH: `0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac`
- USDC: `0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8`
- USDT: `0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8`
- STRK: `0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d`
- Unknown: `0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b`

> ⚠️ **BTC pools:** The default pool deployment doesn't include WBTC/BTC assets. BTC-specific pools likely exist as separate Pool instances created through the PoolFactory. Need to query PoolFactory events or check the Vesu UI for BTC lending markets and their specific pool addresses.

### Current Rates

- Could not extract from Vesu UI (SPA). Check https://vesu.xyz for live BTC lending/borrowing rates.

---

## 3. Other BTC Protocols on Starknet

### Ekubo DEX
- **Website:** https://ekubo.org
- Concentrated liquidity AMM (like Uniswap V3) on Starknet
- Supports BTC pairs (WBTC/ETH, WBTC/USDC, etc.)
- LP positions earn trading fees
- Likely the deepest BTC liquidity on Starknet

### AVNU Aggregator
- **Website:** https://app.avnu.fi
- DEX aggregator routing through Ekubo, JediSwap, and others
- Best execution for BTC swaps on Starknet
- Supports bridge integration

### Other BTC-Adjacent Yield Sources
- **Nostra Finance** — lending/borrowing, may have BTC markets
- **zkLend** — another lending protocol on Starknet
- **JediSwap** — AMM with BTC pairs
- **Starknet native staking** — via Endur for STRK (not BTC directly, but relevant for STRK rewards)

### BTC Variants on Starknet
| Token | Source | Notes |
|---|---|---|
| WBTC | Ethereum bridge | Most liquid, widely supported |
| tBTC | Threshold Network | Decentralized BTC bridge |
| LBTC | Lombard Finance | Bitcoin liquid staking |
| SolvBTC | Solv Protocol | BTC yield token |

---

## 4. Testnet Availability

### What's on Sepolia

| Protocol | Sepolia Status |
|---|---|
| Endur (xSTRK) | ✅ Available |
| Endur (BTC LSTs) | ❌ "Work in progress" |
| Vesu V2 | ❓ Unknown — deployment.json only shows mainnet addresses |
| Ekubo | ❓ Likely has testnet but BTC pairs may lack liquidity |
| AVNU | ❓ Aggregator works on testnet but limited pools |

### Recommendation for Hackathon

1. **STRK staking flow** can be tested on Sepolia via Endur
2. **BTC flows will likely need mainnet fork** — Endur BTC LSTs are mainnet-only, Vesu BTC pools are mainnet
3. Consider using **Starknet Devnet** or **Katana** (from Dojo) for local testing with mock contracts
4. Alternative: Build against mainnet contracts in read-only mode, test writes on devnet with forked state

---

## 5. BTCFi Season — 100M STRK Incentive Program

### Overview

The Starknet Foundation announced a **"BTCFi Season"** — a major incentive program allocating **100 million STRK tokens** (from the DeFi Spring allocation) to bootstrap Bitcoin DeFi activity on Starknet.

### Key Details (based on ecosystem knowledge)

- **Goal:** Make Starknet a premier destination for BTC DeFi
- **Mechanism:** STRK rewards distributed to users who deposit BTC variants (WBTC, tBTC, LBTC, SolvBTC) into participating DeFi protocols
- **Participating Protocols:** Endur, Vesu, Ekubo, Nostra, and others in the Starknet DeFi ecosystem
- **Impact on Yields:**
  - Base yields from lending/LP fees remain the same
  - **Additional STRK incentives** significantly boost effective APY
  - Endur BTC LSTs earn staking rewards + STRK incentives
  - Vesu BTC lending pools earn interest + STRK incentives
  - Combined yields could be significantly higher than base rates during the incentive period

### Significance for Hackathon

- **Massive TVL influx** — BTC capital flowing into Starknet DeFi
- **High yields** = strong user incentive for a yield optimizer/aggregator
- **Multiple yield sources** that can be composed:
  1. Deposit BTC → Endur LST (base yield + STRK incentives)
  2. Supply LST to Vesu (lending yield + STRK incentives)
  3. LP on Ekubo with BTC pairs (fees + STRK incentives)
- A **BTC yield aggregator** that auto-routes between these is the ideal hackathon project

---

## 6. Hackathon Strategy Implications

### Architecture: BTC Yield Optimizer on Starknet

```
User deposits BTC variant (WBTC/tBTC/LBTC/SolvBTC)
        │
        ▼
   [Smart Contract: Vault/Router]
        │
        ├──► Endur: Mint LST (xWBTC/xtBTC/etc) — ERC4626 deposit()
        │         │
        │         ├──► Vesu: Supply LST as collateral — vToken deposit()
        │         └──► Ekubo: LP with LST pairs
        │
        ├──► Vesu: Direct supply BTC to lending pool — vToken deposit()
        │
        └──► Ekubo: Direct LP with BTC pairs
```

### Key Integration Points

1. **Endur LSTs:** ERC-4626 `deposit(assets, receiver)` — straightforward
2. **Vesu V2:** ERC-4626 vToken `deposit(assets, receiver)` OR `Pool.manage_position()`
3. **Ekubo:** Concentrated liquidity — more complex, need to manage tick ranges
4. **AVNU:** For BTC variant swaps between strategies

### Critical Questions Still Open

- [ ] Exact BTC pool addresses on Vesu (need to query PoolFactory or check UI)
- [ ] Live APY numbers from Endur and Vesu for BTC
- [ ] Whether Vesu has vTokens for Endur LSTs (composability)
- [ ] Ekubo pool addresses for BTC pairs
- [ ] BTCFi Season exact reward mechanics and distribution schedule
- [ ] Testnet strategy — likely need mainnet fork for full BTC testing
