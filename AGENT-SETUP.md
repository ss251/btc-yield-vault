# Starknet Agent Kit (Snak) - Setup & Architecture Notes

## Overview

Snak is an AI agent framework by Kasar Labs, built on **LangChain/LangGraph** with a NestJS server. It enables autonomous agents that can interact with Starknet and other blockchains via plugins and MCP servers.

## Repository Structure

```
snak/
├── packages/
│   ├── agent/       # Core agent logic (LangGraph graphs, tools, operators)
│   ├── core/        # Shared types, config, logging, validation
│   ├── server/      # NestJS HTTP/WebSocket server
│   ├── database/    # PostgreSQL integration (checkpointing, memory)
│   ├── metrics/     # Prometheus metrics
│   └── workers/     # Background workers
├── plugins/         # Custom plugins (artpeace, rpc schemas)
├── config/
│   ├── agents/      # Agent configuration files (*.agent.json)
│   ├── models/      # Model configuration (fast/smart/cheap)
│   └── guards/      # Safety guardrails
└── tests/
```

## Architecture

### Agent Lifecycle
1. **Config Loading**: Agent config JSON defines profile, MCP servers, model, memory settings
2. **Tool Initialization** (`packages/agent/src/tools/tools.ts`):
   - MCP tools loaded from configured MCP servers via `@langchain/mcp-adapters`
   - Core tools added (end_task, block_task, ask_human)
   - Supervisor tools if running in supervisor mode
3. **Graph Creation**: LangGraph state machine orchestrates task management, execution, memory, and verification
4. **Execution**: Streaming events via `streamEvents()` with checkpointing in PostgreSQL

### Key Components
- **SnakAgent** (`packages/agent/src/agents/core/snakAgent.ts`): Main agent class
- **BaseAgent** (`baseAgent.ts`): Abstract base with common init logic
- **CoreToolRegistry** (`packages/agent/src/agents/graphs/tools/core.tools.ts`): Built-in tools
- **MCP Service** (`packages/agent/src/services/mcp/src/mcp.service.ts`): MCP server management

### How Plugins/Tools Work
Snak uses **MCP (Model Context Protocol)** as the primary tool integration mechanism:

```json
{
  "mcp_servers": {
    "my-tool": {
      "command": "node",
      "args": ["/path/to/mcp-server/dist/index.js"],
      "env": { "API_KEY": "..." }
    }
  }
}
```

The MCP server runs as a subprocess communicating via stdio. Tools are auto-discovered via the MCP protocol and exposed to the LangChain agent as `DynamicStructuredTool` instances.

### Model Configuration
Models are configured per-agent in the `graph.model` section:
- **provider**: `anthropic`, `google-genai`, `openai`, `ollama`, `deepseek`
- **model_name**: The specific model identifier
- **temperature**: Sampling temperature
- **max_tokens**: Max output tokens

## Our Custom Setup

### Xverse MCP Server (`/starknet-hackathon/xverse-mcp-server/`)

Custom MCP server wrapping the Xverse Bitcoin API with 6 tools:

| Tool | Description | API Endpoint |
|------|-------------|-------------|
| `get_btc_balance` | Confirmed + unconfirmed BTC balance | `GET /v1/bitcoin/address/{addr}/balance` |
| `get_btc_utxos` | List confirmed UTXOs | `GET /v1/bitcoin/address/{addr}/utxo` |
| `get_ordinals_inscriptions` | List Ordinals inscriptions | `GET /v1/ordinals/address/{addr}/inscriptions` |
| `get_runes_balances` | Runes token balances | `GET /v1/ordinals/address/{addr}/runes` |
| `register_portfolio_address` | Register for portfolio tracking | `POST /v1/portfolio/register` |
| `get_btc_address_summary` | Combined balance + UTXO summary | Multiple endpoints |

### Agent Config (`config/agents/xverse-btc.agent.json`)
- Uses **Claude claude-sonnet-4-20250514** via Anthropic
- Xverse MCP server for Bitcoin data
- Focused on portfolio analysis objectives
- Memory/RAG disabled for simplicity (can enable later)

### API Details
- **Base URL**: `https://api.secretkeylabs.io`
- **Auth**: `x-api-key` header
- **Rate Limits**: 2 RPS (100 RPM), 10-day trial
- **Key**: `REDACTED_API_KEY`

## Running

### Prerequisites
- Node.js 16+, pnpm 9+
- PostgreSQL (for Snak's checkpointing/memory — via `docker compose -f docker-compose.dev.yml up -d`)
- `ANTHROPIC_API_KEY` env var

### Quick Start
```bash
# 1. Build MCP server
cd /Users/thescoho/Developer/starknet-hackathon/xverse-mcp-server
npm install && npm run build

# 2. Install Snak deps
cd /Users/thescoho/Developer/starknet-hackathon/agent
pnpm install

# 3. Test API endpoints
cd /Users/thescoho/Developer/starknet-hackathon
npx tsx test-xverse-api.ts

# 4. Start Snak server (needs Docker for PostgreSQL)
cd /Users/thescoho/Developer/starknet-hackathon/agent
pnpm start:server
```

### Testing the MCP Server Standalone
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | \
  XVERSE_API_KEY="REDACTED_API_KEY" \
  node /Users/thescoho/Developer/starknet-hackathon/xverse-mcp-server/dist/index.js
```

## Verified API Endpoints (Real Data)
All endpoints tested successfully against mainnet:
- ✅ Balance: Returns confirmed/unconfirmed sats with tx counts
- ✅ UTXOs: Returns UTXO list with txid, vout, value, confirmation status
- ✅ Inscriptions: Returns ordinals with content URLs, collection info
- ✅ Runes: Returns rune balances with indexer height
- ✅ Portfolio Register: 200 OK, no body

## Next Steps
- [ ] Set up PostgreSQL via Docker for Snak's checkpointer
- [ ] Set `ANTHROPIC_API_KEY` and test full agent flow
- [ ] Add more Bitcoin addresses for richer testing
- [ ] Consider adding BRC-20 and Spark endpoints
- [ ] Add cross-chain swap tools for bridging BTC ↔ Starknet
