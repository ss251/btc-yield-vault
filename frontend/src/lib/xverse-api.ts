import { XVERSE_API_BASE, XVERSE_API_KEY } from "./constants";

interface BalanceResponse {
  address: string;
  balance: string; // in sats
}

interface Ordinal {
  id: string;
  content_type: string;
  number: number;
}

const headers = {
  "x-api-key": XVERSE_API_KEY,
  "Content-Type": "application/json",
};

export async function fetchBtcBalance(address: string): Promise<number> {
  try {
    const res = await fetch(`${XVERSE_API_BASE}/v1/address/${address}/balance`, { headers });
    if (!res.ok) return 0;
    const data: BalanceResponse = await res.json();
    return parseInt(data.balance || "0", 10);
  } catch {
    return 0;
  }
}

export async function fetchOrdinals(address: string): Promise<Ordinal[]> {
  try {
    const res = await fetch(`${XVERSE_API_BASE}/v1/address/${address}/ordinals`, { headers });
    if (!res.ok) return [];
    const data = await res.json();
    return data.results || [];
  } catch {
    return [];
  }
}

export function satsToBtc(sats: number): string {
  return (sats / 100_000_000).toFixed(8);
}

export function formatSats(sats: number): string {
  if (sats >= 100_000_000) return `${(sats / 100_000_000).toFixed(4)} BTC`;
  if (sats >= 1_000_000) return `${(sats / 1_000_000).toFixed(2)}M sats`;
  if (sats >= 1_000) return `${(sats / 1_000).toFixed(1)}K sats`;
  return `${sats} sats`;
}

export function formatUsd(sats: number, btcPrice: number = 97500): string {
  const btc = sats / 100_000_000;
  const usd = btc * btcPrice;
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(usd);
}
