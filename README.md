# ZK-Constrained Autonomous Bitcoin Agent

> AI manages your BTC portfolio autonomously. Every decision is constrained by your rules and **ZK-proven on Starknet** via Pedersen commitments — verifiable, trustless, yours.

**Built for the [RE{DEFINE} Starknet Hackathon](https://www.starknet.io/redefine-hackathon/)**

![Cairo](https://img.shields.io/badge/Cairo-2.15-blue) ![Tests](https://img.shields.io/badge/tests-78%2F78-brightgreen) ![Starknet](https://img.shields.io/badge/Starknet-Foundry%200.56-purple) ![License](https://img.shields.io/badge/license-MIT-green)

---

## 🧠 The Problem

Autonomous AI agents managing crypto portfolios are powerful — but how do you **trust** them? Without constraints, an agent could drain your wallet, take excessive risks, or make decisions you'd never approve.

## 💡 The Solution

**ZK-Constrained Autonomous Bitcoin Agent** solves this by making every agent decision **provably correct on-chain**:

1. **Agent observes** your BTC portfolio via Xverse API (balance, UTXOs, ordinals, runes)
2. **Agent decides** on an action (rebalance, catalog ordinals, swap runes)
3. **Decision is ZK-proven** — the ProofRegistry contract re-derives the expected action from the same inputs using Pedersen hash commitments and verifies it matches
4. **Constraints are enforced** — the AgentVault checks daily spend limits, risk thresholds, and allowed action types before approving
5. **Everything is on-chain** — full audit trail of every decision, proof, and approval

```
┌─────────────────────────────────────────────────────────────────┐
│                     Agent Pipeline (TypeScript)                  │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────────────┐    │
│  │  Xverse  │──▶│   Strategy   │──▶│  Propose + Prove     │    │
│  │  API     │   │   Engine     │   │  on Starknet         │    │
│  └──────────┘   └──────────────┘   └──────────┬───────────┘    │
└───────────────────────────────────────────────│────────────────┘
                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Starknet (Cairo Contracts)                  │
│                                                                  │
│  ┌─────────────────┐        ┌──────────────────────────┐        │
│  │ ProofRegistry   │◀──────▶│     AgentVault           │        │
│  │                 │        │                          │        │
│  │ • Pedersen hash │        │ • Constraint checks      │        │
│  │   commitments   │        │ • Daily spend limits     │        │
│  │ • Deterministic │        │ • Risk thresholds        │        │
│  │   re-derivation │        │ • Action type filtering  │        │
│  │ • Proof storage │        │ • Portfolio commitments  │        │
│  └─────────────────┘        └──────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                                                 ▲
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                             │
│  Portfolio · Agent Status · Action History · Constraints Editor   │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Architecture

### Cairo Smart Contracts (`src/`)

| Contract | Lines | Description |
|----------|-------|-------------|
| **ProofRegistry** | 250 | ZK decision verification via Pedersen commitments. Re-derives the expected action from portfolio inputs + strategy params and verifies it matches the agent's proposal. Stores proof history. |
| **AgentVault** | 341 | Constraint enforcement engine. Manages agent registration, daily spend tracking, risk thresholds, action type filtering, and portfolio commitment hashes. Cross-verifies with ProofRegistry. |
| **MultiVault** | 470 | ERC-4626-style vault with multi-strategy allocation (configurable split), rebalancing, and yield distribution. |
| **Vault** | 251 | Single-strategy ERC-4626 vault with deposit/withdraw, share accounting, pause/unpause. |

**78 integration tests** covering all contracts — constraint enforcement, proof verification, vault operations, edge cases, and multi-user scenarios.

### MCP Servers

- **`xverse-mcp-server/`** — 6 tools for Bitcoin portfolio data via Xverse API (balance, UTXOs, ordinals, runes, BRC-20, transactions)
- **`starknet-mcp-server/`** — 6 tools for Starknet interaction (propose/approve actions, read vault state, query proofs)

### Agent Pipeline (`agent-pipeline/run.ts`)

End-to-end autonomous flow:
1. Fetches BTC portfolio from Xverse API
2. Runs deterministic strategy (rebalance > catalog > swap)
3. Computes portfolio commitment (Pedersen hash chain)
4. Submits ZK decision proof to ProofRegistry
5. Proposes action on AgentVault with proof linkage
6. Approves action (triggers constraint validation)

### Frontend (`frontend/`)

Next.js 16 app with:
- **Xverse wallet connection** via `sats-connect`
- **Portfolio panel** — live BTC balance, UTXOs, ordinals, runes
- **Agent status** — real-time agent state and constraint display
- **Action history** — on-chain log of all agent decisions with proof verification status
- **Constraints editor** — configure daily limits, risk thresholds, allowed action types
- **Activity feed** — real-time stream of agent activity

## 🔒 How ZK Verification Works

The ProofRegistry contract enforces **deterministic re-derivation**:

```
Agent submits: (portfolio_inputs, strategy_params, proposed_action)

Contract re-derives:
  1. input_hash  = Pedersen(balance, utxos, ordinals, runes)
  2. strategy_hash = Pedersen(rebalance_threshold, max_risk)
  3. expected_action = deterministic_strategy(portfolio_inputs, strategy_params)
  4. output_hash = Pedersen(action_type, amount, risk_score)

Verification:
  ✅ proposed_action == expected_action  (or reject)
  ✅ risk_score <= max_risk              (or reject)
  ✅ Store proof with all hashes for audit
```

The agent **cannot lie** about its reasoning — the contract independently computes what the action should be and rejects any mismatch.

## 🚀 Quick Start

### Prerequisites

- [Scarb 2.15.1](https://docs.swmansion.com/scarb/download.html)
- [Starknet Foundry 0.56.0](https://foundry-rs.github.io/starknet-foundry/)
- [Node.js 20+](https://nodejs.org/)
- [starknet-devnet 0.7.1](https://github.com/0xSpaceShard/starknet-devnet-rs) (for local testing)

### 1. Run Tests

```bash
cd starknet-hackathon
snforge test
# Expected: Tests: 78 passed, 0 failed
```

### 2. Start Devnet & Deploy

```bash
# Terminal 1: Start devnet
starknet-devnet --seed 0

# Terminal 2: Deploy contracts
cd starknet-hackathon
sncast declare --contract-name ProofRegistry
sncast declare --contract-name AgentVault
# Deploy with constructor args (see snfoundry.toml for account config)
```

### 3. Run Agent Pipeline

```bash
cd agent-pipeline
npm install
npx tsx run.ts
```

Expected output:
```
[Agent] 🚀 ZK-Constrained Autonomous Bitcoin Agent — Pipeline Start
[Agent] ✅ Connected to Starknet devnet
[Agent] Balance: 0.5 BTC, 3 UTXOs, 2 Ordinals, 1 Runes
[Agent] → Submitting ZK decision proof for rebalance...
[Agent] → Proof verified on-chain ✅
[Agent] → Action #0 APPROVED ✅ (ZK-verified + constraint-checked)
[Agent] ✅ Pipeline complete: 1/1 actions approved
```

### 4. Run Frontend

```bash
cd frontend
npm install
npm run dev
# Open http://localhost:3000
```

## 📁 Project Structure

```
starknet-hackathon/
├── src/                        # Cairo smart contracts
│   ├── proof_registry.cairo    # ZK decision verification
│   ├── agent_vault.cairo       # Constraint enforcement
│   ├── multi_vault.cairo       # Multi-strategy ERC-4626 vault
│   ├── vault.cairo             # Single-strategy vault
│   ├── interfaces.cairo        # Contract interfaces
│   └── mocks.cairo             # Test mocks
├── tests/                      # 78 integration tests
│   ├── test_proof_registry.cairo
│   ├── test_agent_vault.cairo
│   ├── test_multi_vault.cairo
│   └── test_contract.cairo
├── agent-pipeline/
│   └── run.ts                  # Autonomous agent pipeline
├── xverse-mcp-server/          # Bitcoin MCP server (6 tools)
├── starknet-mcp-server/        # Starknet MCP server (6 tools)
├── frontend/                   # Next.js dashboard
├── Scarb.toml                  # Cairo project config
└── snfoundry.toml              # Starknet Foundry config
```

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Cairo 2.15, Starknet, OpenZeppelin |
| ZK Proofs | Pedersen hash commitments (native Cairo) |
| Agent Runtime | TypeScript, starknet.js |
| MCP Servers | Model Context Protocol SDK |
| Bitcoin Data | Xverse API |
| Frontend | Next.js 16, React 19, Tailwind CSS 4 |
| Wallet | Xverse (sats-connect) |
| Testing | Starknet Foundry (snforge) |

## 📜 Devnet Deployment

Latest deployment on starknet-devnet:
- **ProofRegistry**: `0x03673bedfe85fd5f12b9fa5dcf06d84a05143cb7fb55a2367dee43215caed5b3`
- **AgentVault**: `0x00feed60bab3040d068f6d8976a2dc05b3e7b17bedaa88bc58d8382c4d85b3f2`

## 📄 License

MIT
