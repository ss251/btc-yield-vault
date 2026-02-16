"use client";

import { Bitcoin, Gem, Coins } from "lucide-react";
import { useXverseWallet } from "@/providers/XverseProvider";
import { useBtcPortfolio } from "@/hooks/useBtcPortfolio";
import { DEMO_BTC_ADDRESS } from "@/lib/constants";

export function PortfolioPanel() {
  const { btcAddress, connected } = useXverseWallet();
  const address = btcAddress || DEMO_BTC_ADDRESS;
  const { balance: rawBalance, ordinals, runes, loading } = useBtcPortfolio(address);
  const btcPrice = 97500;

  const balance = rawBalance || 234_567_890; // fallback demo balance

  const btcAmount = balance / 100_000_000;
  const usdValue = btcAmount * btcPrice;

  return (
    <div className="bg-dark-card border border-dark-border rounded-2xl p-6 animate-fade-in">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-sm font-medium text-gray-400 uppercase tracking-wider">Portfolio</h2>
        <div className="flex items-center gap-1.5 text-xs text-gray-500">
          <div className={`w-1.5 h-1.5 rounded-full ${connected ? "bg-success" : "bg-warning"}`} />
          {connected ? "Live" : "Demo"}
        </div>
      </div>

      <div className="mb-6">
        <div className="flex items-baseline gap-2 mb-1">
          <span className="text-3xl font-bold tracking-tight">
            {loading ? (
              <span className="inline-block w-40 h-8 bg-dark-border rounded animate-pulse" />
            ) : (
              `${btcAmount.toFixed(4)} BTC`
            )}
          </span>
        </div>
        <span className="text-sm text-gray-500">
          {loading ? "..." : `≈ $${usdValue.toLocaleString("en-US", { maximumFractionDigits: 0 })}`}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <StatMini icon={<Bitcoin className="w-3.5 h-3.5" />} label="BTC Price" value={`$${btcPrice.toLocaleString()}`} />
        <StatMini icon={<Gem className="w-3.5 h-3.5" />} label="Ordinals" value={ordinals.length > 0 ? String(ordinals.length) : "—"} />
        <StatMini icon={<Coins className="w-3.5 h-3.5" />} label="Runes" value={runes.length > 0 ? String(runes.length) : "—"} />
      </div>
    </div>
  );
}

function StatMini({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="bg-dark-surface border border-dark-border rounded-xl p-3">
      <div className="flex items-center gap-1.5 text-gray-500 mb-1">
        {icon}
        <span className="text-[10px] uppercase tracking-wider">{label}</span>
      </div>
      <span className="text-sm font-semibold">{value}</span>
    </div>
  );
}
