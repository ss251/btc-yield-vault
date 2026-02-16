# RE{DEFINE} Hackathon — Winning Strategy

## 📋 Hackathon Overview

**Event:** RE{DEFINE} Hackathon by Starknet Foundation on DoraHacks
**Tracks:** Privacy | **Bitcoin** | Wildcard
**Timeline:** Feb 1 – Feb 28, 2026 (judging Mar 1–14, winners Mar 14)
**Submission:** Working demo (testnet/mainnet) + GitHub repo + 500-word description + **3-min video demo** + Starknet wallet

### Bitcoin Track Prizes
- **Cash:** $9,675 STRK (split across 1st/2nd/3rd in Bitcoin track, part of $21,500 total)
- **In-kind (Xverse):**
  - 1st: Pro Launch Package ($2,500) — 4mo Pro Plan + Bitcoin RPC + mentorship
  - 2nd: Pro Growth Package ($1,800) — 3mo Pro Plan + Bitcoin RPC + mentorship
  - 3rd: Pro Kickstart Package ($1,200) — 2mo Pro Plan + Bitcoin RPC + onboarding

### Hackathon Narrative (from organizers)
> "Privacy is the institutional priority for 2026. Starknet is the Bitcoin DeFi Layer with quantum-safe ZK tech."

Bitcoin track asks for: **BTC-native DeFi leveraging Starknet's security, bridges, atomic swaps, OP_CAT apps**

---

## 🎯 Our Project: One-Click BTC → Starknet Yield Vault

### Architecture
```
BTC (user wallet) → Bridge to Starknet → Endur LST (liquid staking) → Vesu (lending yield) → Compounding vault
```

### Core Value Prop
Bitcoin holders can earn yield on their BTC with a single click — no manual bridging, swapping, staking, or lending. Abstract away all the DeFi complexity.

---

## 🏆 What Wins Hackathons (General Patterns)

### 1. **Working Demo > Everything**
Judges spend 3 minutes on your video. If it doesn't work on screen, it doesn't exist.
- Deploy on **testnet minimum**, mainnet if possible
- Show real transactions, not mockups
- Record the happy path flawlessly

### 2. **Narrative Clarity**
Winners answer "why does this matter?" in 10 seconds:
- ❌ "We built a yield aggregator on Starknet"
- ✅ "Bitcoin holders have $1.2T sitting idle. We let them earn yield in one click without leaving Bitcoin."

### 3. **Innovation / Technical Depth**
Judges reward novel use of the platform's unique features:
- Use **Cairo** contracts (not just a frontend wrapper)
- Leverage **ZK proofs** if possible (even for proof of reserve / audit)
- Show composability between Starknet protocols (Endur + Vesu = ecosystem play)

### 4. **Completeness**
- Clean README, architecture diagram, clear code structure
- Deployed contracts with verified source
- Error handling, not just happy path

### 5. **Real Utility**
Projects that solve a real pain point > cool tech demos. BTC yield is a *massive* real problem.

---

## 💰 BTC DeFi Vault Landscape — What Works

### Badger DAO (Peak TVL: $2.4B)
**What made it successful:**
- **BTC-first branding** — everything was about making Bitcoin productive in DeFi
- **Sett Vaults** — auto-compounding yield strategies for wBTC/renBTC
- **One-click deposit** — user deposits BTC asset, vault handles strategy
- **Governance + incentives** — BADGER token emissions bootstrapped TVL
- **Lesson:** BTC holders are conservative. Trust and simplicity win over complexity.

### Yearn Finance (wBTC Vaults)
**What made it successful:**
- **Strategy abstraction** — users deposit, vault allocates across lending protocols
- **Auto-compounding** — no manual harvesting
- **Battle-tested contracts** — security reputation was everything
- **Lesson:** The best yield vault UX is "deposit and forget."

### SolvBTC / Solv Protocol
**What made it successful:**
- **Bitcoin reserve token** model — wrap BTC into yield-bearing asset
- **Multi-chain** — available across chains
- **Lesson:** Yield-bearing BTC wrapper is a powerful narrative

### Key UX Patterns from Successful BTC Vaults
| Pattern | Why It Works |
|---------|-------------|
| One-click deposit | BTC holders hate complexity |
| Auto-compounding | Set-and-forget appeals to BTC hodlers |
| Clear APY display | Trust through transparency |
| Withdrawal anytime | No lockups = more deposits |
| Portfolio dashboard | Show earnings in BTC terms, not USD |
| Risk rating / audit badges | BTC holders are security-paranoid |

---

## 🚀 Strategy to Maximize Our Chances

### Priority 1: NAIL THE DEMO (50% of winning)
- **3-minute video** must tell a story:
  - 0:00–0:30 — Problem: "$1.2T in Bitcoin earning nothing"
  - 0:30–1:00 — Solution: One-click vault, show the UI
  - 1:00–2:15 — Live demo: Connect wallet → deposit BTC → see it flow through bridge → Endur LST → Vesu → show yield accruing
  - 2:15–2:45 — Architecture diagram + Cairo contracts
  - 2:45–3:00 — Future vision + team
- **Record multiple takes.** Edit for polish. Add captions.

### Priority 2: COMPOSABILITY STORY (differentiator)
This is what judges love about ecosystem hackathons — **show Starknet's composability**:
- Bridge (BTC→Starknet) + Endur (liquid staking) + Vesu (lending) = **3 protocols in one tx**
- Frame it as: "Only possible on Starknet because of native account abstraction + Cairo composability"
- If possible, batch operations into a **multicall** using Starknet's AA

### Priority 3: INNOVATION HOOKS (judge bait)
Pick 1-2 of these to implement:
- **🔥 Smart Rebalancing:** Auto-switch between Endur staking and Vesu lending based on which has higher APY
- **🔥 ZK Proof of Reserves:** Generate a STARK proof that the vault's BTC backing is verifiable on-chain
- **Xverse Integration:** Use Xverse wallet/API directly (they're the sponsor — judges will notice)
- **Risk Tranches:** Simple/aggressive yield tiers for different risk appetites
- **Yield denominated in BTC:** Always show returns in sats, not USD or STRK

### Priority 4: NARRATIVE ALIGNMENT
Hit every keyword the organizers care about:
- ✅ "BTC-native DeFi" — our core
- ✅ "Leveraging Starknet's security" — ZK rollup = BTC security inheritance
- ✅ "Trust-minimized" — non-custodial vault, user controls funds
- ✅ "Bitcoin DeFi Layer" — frame Starknet as THE place for BTC yield
- Optional: mention OP_CAT potential for future trustless bridging

### Priority 5: PRESENTATION QUALITY
- **Clean UI** — use a good component library, dark theme (BTC aesthetic)
- **Architecture diagram** in README
- **Deployed contracts** on testnet with links
- **Clear README** with setup instructions
- Show **gas costs** and **yield projections**

---

## ⚠️ Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Bridge integration is complex | Use existing bridge (e.g., StarkGate) + mock BTC deposit for demo |
| Endur/Vesu API changes | Pin versions, have fallback mock data |
| Time constraint (12 days left) | Focus on happy path only, no edge cases |
| Competition in Bitcoin track | Differentiate via UX polish + composability story |

---

## 📐 Minimum Viable Submission (if time is tight)

If we can't build everything, prioritize in this order:
1. **Smart contract** that deposits into Endur + Vesu (Cairo)
2. **Frontend** with one-click deposit flow
3. **3-minute video** showing the flow working
4. Clean **README** + architecture diagram
5. *Nice to have:* Auto-compounding, rebalancing, ZK proofs

---

## 🎬 Project Name Ideas
- **SatVault** — simple, BTC-native branding
- **BitYield** — clear value prop
- **OneBTC** — emphasizes one-click
- **BTCellar** — vault/cellar metaphor (wine cellar vibes)
- **Satoshi's Vault** — narrative-driven

---

## 📝 Key Takeaway

> **The winning formula = Real problem (idle BTC) + Clean demo (one-click UX) + Ecosystem composability (Endur+Vesu) + Narrative alignment (BTC DeFi Layer) + Polish (video, README, deployed contracts)**

Don't over-engineer. A polished simple product beats a broken complex one every time.
