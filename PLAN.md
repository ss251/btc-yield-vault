# ZK-Constrained Autonomous Bitcoin Agent

## One-Liner
An AI agent that manages your Bitcoin portfolio, but every decision is ZK-proven correct on Starknet before execution — portfolio stays private, constraints are enforced cryptographically.

## Why This Wins
- **AI agents** = hottest crypto narrative (nobody in hackathon has this)
- **Bitcoin track**: Real BTC transactions via Xverse PSBTs
- **Privacy track**: Hidden portfolio, private constraints, ZK-proven decisions
- **Xverse sponsor**: Deep API usage (portfolio, UTXOs, Ordinals, Runes, signing)
- One codebase → submit to BOTH tracks

## Architecture

```
User (Xverse Wallet)
    │
    ├── sats-connect → BTC address + Starknet address
    │
    └── Xverse API → Real portfolio data
            │
            ▼
    ┌─────────────────┐
    │   AI Agent       │ (off-chain, LLM-powered)
    │   - Analyzes BTC │
    │   - Proposes     │
    │     actions      │
    └────────┬────────┘
             │ action proposal
             ▼
    ┌─────────────────┐
    │  Cairo Contract  │ (on-chain, Starknet)
    │  - Verify ZK     │
    │    constraints    │
    │  - Check limits   │
    │  - Approve/deny   │
    └────────┬────────┘
             │ if approved
             ▼
    ┌─────────────────┐
    │  Execute Action  │
    │  - Sign PSBT     │
    │    (via Xverse)  │
    │  - Starknet tx   │
    └─────────────────┘
```

## Stack
- **Wallet**: sats-connect (Xverse → BTC + Starknet)
- **Data**: Xverse REST API (portfolio, UTXOs, Ordinals, Runes, market)
- **AI**: Off-chain LLM reasoning (Claude/GPT via API)
- **ZK**: Giza/Orion (tiny ONNX model → Cairo verifier) OR custom Cairo constraint checker
- **Agent**: Starknet Agent Kit (Snak) with AA + session keys
- **Contract**: Cairo — constraint verification + proof registry + agent state
- **Bridge**: Atomiq (optional — trustless BTC ↔ wBTC)
- **Frontend**: Next.js + sats-connect + Tailwind

## Cairo Contract: AgentVault
```
- deploy(owner, constraints)
- propose_action(action_type, params, proof)
- verify_constraints(action, proof) → bool
- execute(action_id) → approved actions only
- get_agent_state() → current state
- update_constraints(new_constraints) — owner only
```

### Constraint Types
- Max spend per day (in sats)
- Whitelisted action types (swap, bridge, lend)
- Risk threshold (max drawdown %)
- Asset allocation limits
- Time restrictions

## 10-Day Roadmap
- **Day 1-2**: Agent Kit + sats-connect skeleton, Xverse API integration, fetch real portfolio
- **Day 3-4**: Cairo constraint contract (deploy, propose, verify, execute), tests
- **Day 5-6**: AI decision engine (off-chain LLM), action proposal flow
- **Day 7**: Giza zkML integration (tiny model for risk scoring → Cairo proof)
- **Day 8**: Frontend — connect wallet, set constraints, monitor agent
- **Day 9**: Polish, end-to-end demo, deploy to Sepolia
- **Day 10**: Demo video (3 min), README, submission

## Demo Script
1. Connect Xverse wallet → show real BTC portfolio
2. Set agent constraints on Starknet ("max 0.01 BTC/day, only swap if slippage < 2%")
3. Agent analyzes portfolio using Xverse API
4. Agent proposes action → Cairo contract verifies constraints
5. ZK proof generated → action approved
6. BTC transaction executes via Xverse PSBT signing
7. Show proof hash on Starknet explorer
8. "You didn't build an AI wallet. You built a cryptographically bounded autonomous agent."

## Xverse API Endpoints Needed
- Portfolio: GET /v1/address/{address}/balance
- UTXOs: GET /v1/address/{address}/utxo
- Ordinals: GET /v1/address/{address}/ordinals
- Runes: GET /v1/address/{address}/runes
- Market: GET /v1/swaps/get-quotes
- Signing: sats-connect signPsbt

## Research Files
- CRITIQUE-GROK.md, CRITIQUE-GPT.md, CRITIQUE-CLAUDE.md
- PIVOT-IDEAS.md
- XVERSE-INTEGRATION.md
- BTC-DEFI-LANDSCAPE.md
- STRATEGY.md
