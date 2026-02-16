#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
const BASE_URL = process.env.XVERSE_API_BASE_URL || "https://api.secretkeylabs.io";
const API_KEY = process.env.XVERSE_API_KEY || "";
async function xverseGet(path) {
    const url = `${BASE_URL}${path}`;
    const res = await fetch(url, {
        headers: {
            "x-api-key": API_KEY,
            "Accept": "application/json",
        },
    });
    if (!res.ok) {
        const text = await res.text();
        throw new Error(`Xverse API ${res.status}: ${text}`);
    }
    return res.json();
}
async function xversePost(path, body) {
    const url = `${BASE_URL}${path}`;
    const res = await fetch(url, {
        method: "POST",
        headers: {
            "x-api-key": API_KEY,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body: JSON.stringify(body),
    });
    if (!res.ok) {
        const text = await res.text();
        throw new Error(`Xverse API ${res.status}: ${text}`);
    }
    return res.json();
}
const server = new McpServer({
    name: "xverse-bitcoin",
    version: "1.0.0",
});
// Tool: Get BTC Balance
server.tool("get_btc_balance", "Get confirmed and unconfirmed BTC balance for a Bitcoin address", {
    address: z.string().min(10).describe("Bitcoin address (e.g. bc1q...)"),
}, async ({ address }) => {
    const data = await xverseGet(`/v1/bitcoin/address/${address}/balance`);
    return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
});
// Tool: Get UTXOs
server.tool("get_btc_utxos", "Get confirmed UTXOs for a Bitcoin address", {
    address: z.string().min(10).describe("Bitcoin address"),
    offset: z.number().optional().default(0).describe("Pagination offset"),
    limit: z.number().optional().default(25).describe("Results limit (min 25, max 5000)"),
}, async ({ address, offset, limit }) => {
    const data = await xverseGet(`/v1/bitcoin/address/${address}/utxo?offset=${offset}&limit=${limit}`);
    return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
});
// Tool: Get Ordinals Inscriptions
server.tool("get_ordinals_inscriptions", "List all confirmed Ordinals inscriptions owned by a Bitcoin address", {
    address: z.string().min(10).describe("Bitcoin address"),
    offset: z.number().optional().default(0).describe("Pagination offset"),
    limit: z.number().optional().default(60).describe("Results limit"),
}, async ({ address, offset, limit }) => {
    const data = await xverseGet(`/v1/ordinals/address/${address}/inscriptions?offset=${offset}&limit=${limit}`);
    return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
});
// Tool: Get Runes Balances
server.tool("get_runes_balances", "Get Runes token balances for a Bitcoin address", {
    address: z.string().min(10).describe("Bitcoin address"),
    offset: z.number().optional().default(0).describe("Pagination offset"),
    limit: z.number().optional().default(60).describe("Results limit"),
}, async ({ address, offset, limit }) => {
    const data = await xverseGet(`/v1/ordinals/address/${address}/runes?offset=${offset}&limit=${limit}`);
    return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
});
// Tool: Register Portfolio Address
server.tool("register_portfolio_address", "Register a Bitcoin address for portfolio tracking. Must be called before fetching portfolio data.", {
    address: z.string().min(10).describe("Bitcoin address to track"),
    assetType: z.string().optional().default("bitcoin").describe("Asset type (default: bitcoin)"),
}, async ({ address, assetType }) => {
    const data = await xversePost("/v1/portfolio/register", {
        assetType,
        addresses: [address],
    });
    return {
        content: [{ type: "text", text: JSON.stringify(data ?? { status: "registered" }, null, 2) }],
    };
});
// Tool: Get Bitcoin Address Summary (combines balance + basic info)
server.tool("get_btc_address_summary", "Get a comprehensive summary of a Bitcoin address including balance, transaction count, and funded/spent totals", {
    address: z.string().min(10).describe("Bitcoin address"),
}, async ({ address }) => {
    // Fetch balance and UTXOs in parallel for a summary
    const [balance, utxos] = await Promise.all([
        xverseGet(`/v1/bitcoin/address/${address}/balance`),
        xverseGet(`/v1/bitcoin/address/${address}/utxo?offset=0&limit=25`),
    ]);
    const confirmedBalance = (balance.confirmed?.fundedTxoSum ?? 0) - (balance.confirmed?.spentTxoSum ?? 0);
    const unconfirmedBalance = (balance.unconfirmed?.fundedTxoSum ?? 0) - (balance.unconfirmed?.spentTxoSum ?? 0);
    const summary = {
        address,
        confirmedBalanceSats: confirmedBalance,
        confirmedBalanceBTC: confirmedBalance / 1e8,
        unconfirmedBalanceSats: unconfirmedBalance,
        unconfirmedBalanceBTC: unconfirmedBalance / 1e8,
        totalTxCount: balance.confirmed?.txCount ?? 0,
        utxoCount: utxos?.results?.length ?? utxos?.length ?? 0,
        hasMore: utxos?.hasMore ?? false,
        raw: { balance, utxoSample: utxos },
    };
    return {
        content: [{ type: "text", text: JSON.stringify(summary, null, 2) }],
    };
});
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("Xverse MCP Server running on stdio");
}
main().catch((err) => {
    console.error("Fatal:", err);
    process.exit(1);
});
