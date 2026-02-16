"use client";

import { useState, useEffect } from "react";
import { Settings, Save, Power, PowerOff, AlertCircle, CheckCircle2 } from "lucide-react";
import { useAgentVault } from "@/hooks/useAgentVault";
import { updateConstraints } from "@/lib/contracts";

// Action type bitmap: bit 0 = rebalance (1), bit 1 = catalog (2), bit 2 = swap (4)
const ACTION_FLAGS = [
  { label: "Rebalance", bit: 1 },
  { label: "Catalog", bit: 2 },
  { label: "Swap", bit: 4 },
] as const;

export function ConstraintsEditor() {
  const { agentState, usingMock, refetch } = useAgentVault();
  const c = agentState.constraints;

  const [maxDaily, setMaxDaily] = useState(c.maxDailySpend);
  const [maxSingleTx, setMaxSingleTx] = useState(c.maxSingleTx);
  const [riskThreshold, setRiskThreshold] = useState(c.riskThreshold);
  const [allowedBitmap, setAllowedBitmap] = useState(c.allowedActionTypes);
  const [isActive, setIsActive] = useState(c.isActive);
  const [saving, setSaving] = useState(false);
  const [txStatus, setTxStatus] = useState<"idle" | "success" | "error">("idle");
  const [txError, setTxError] = useState("");

  // Sync from contract state when it changes
  useEffect(() => {
    setMaxDaily(c.maxDailySpend);
    setMaxSingleTx(c.maxSingleTx);
    setRiskThreshold(c.riskThreshold);
    setAllowedBitmap(c.allowedActionTypes);
    setIsActive(c.isActive);
  }, [c]);

  const toggleBit = (bit: number) => {
    setAllowedBitmap((prev) => prev ^ bit);
  };

  const handleSave = async () => {
    setSaving(true);
    setTxStatus("idle");
    setTxError("");
    try {
      await updateConstraints(
        BigInt(maxDaily),
        BigInt(allowedBitmap),
        BigInt(maxSingleTx),
        riskThreshold,
        isActive
      );
      setTxStatus("success");
      refetch();
      setTimeout(() => setTxStatus("idle"), 3000);
    } catch (err) {
      console.error("update_constraints failed:", err);
      setTxStatus("error");
      setTxError(err instanceof Error ? err.message : "Transaction failed");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="bg-dark-card border border-dark-border rounded-2xl p-6 animate-fade-in">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-sm font-medium text-gray-400 uppercase tracking-wider flex items-center gap-2">
          <Settings className="w-4 h-4" /> Constraints
          {usingMock && (
            <span className="text-[10px] text-warning bg-warning/10 px-1.5 py-0.5 rounded">
              Demo
            </span>
          )}
        </h2>
        <button
          onClick={() => setIsActive(!isActive)}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
            isActive
              ? "bg-success/10 text-success border border-success/20 hover:bg-success/20"
              : "bg-danger/10 text-danger border border-danger/20 hover:bg-danger/20"
          }`}
        >
          {isActive ? (
            <Power className="w-3 h-3" />
          ) : (
            <PowerOff className="w-3 h-3" />
          )}
          {isActive ? "Active" : "Paused"}
        </button>
      </div>

      <div className="space-y-5">
        {/* Max Daily Spend */}
        <div>
          <label className="block text-xs text-gray-400 mb-2">
            Max Daily Spend (sats)
          </label>
          <input
            type="number"
            value={maxDaily}
            onChange={(e) => setMaxDaily(Number(e.target.value))}
            className="w-full px-3 py-2.5 bg-dark-surface border border-dark-border rounded-lg text-sm text-white focus:border-btc focus:outline-none transition-colors"
          />
          <div className="flex justify-between text-[10px] text-gray-600 mt-1">
            <span>
              ≈ {((maxDaily / 100_000_000) * 97500).toFixed(2)} USD
            </span>
            <span>{(maxDaily / 100_000_000).toFixed(6)} BTC</span>
          </div>
        </div>

        {/* Max Single Tx */}
        <div>
          <label className="block text-xs text-gray-400 mb-2">
            Max Single Transaction (sats)
          </label>
          <input
            type="number"
            value={maxSingleTx}
            onChange={(e) => setMaxSingleTx(Number(e.target.value))}
            className="w-full px-3 py-2.5 bg-dark-surface border border-dark-border rounded-lg text-sm text-white focus:border-btc focus:outline-none transition-colors"
          />
        </div>

        {/* Risk Threshold */}
        <div>
          <div className="flex justify-between mb-2">
            <label className="text-xs text-gray-400">Risk Threshold</label>
            <span className="text-xs font-mono text-btc">{riskThreshold}</span>
          </div>
          <input
            type="range"
            min={0}
            max={255}
            value={riskThreshold}
            onChange={(e) => setRiskThreshold(Number(e.target.value))}
            className="w-full h-1.5 bg-dark-surface rounded-full appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-btc [&::-webkit-slider-thumb]:cursor-pointer"
          />
          <div className="flex justify-between text-[10px] text-gray-600 mt-1">
            <span>Conservative</span>
            <span>Aggressive</span>
          </div>
        </div>

        {/* Allowed Actions (bitmap) */}
        <div>
          <label className="block text-xs text-gray-400 mb-2">
            Allowed Actions
          </label>
          <div className="flex flex-wrap gap-2">
            {ACTION_FLAGS.map(({ label, bit }) => (
              <button
                key={label}
                onClick={() => toggleBit(bit)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                  allowedBitmap & bit
                    ? "bg-btc/15 text-btc border border-btc/30"
                    : "bg-dark-surface text-gray-500 border border-dark-border hover:border-dark-border-hover"
                }`}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="text-[10px] text-gray-600 mt-1 font-mono">
            Bitmap: {allowedBitmap} (0b{allowedBitmap.toString(2).padStart(3, "0")})
          </div>
        </div>

        {/* Status messages */}
        {txStatus === "success" && (
          <div className="flex items-center gap-2 text-xs text-success bg-success/10 border border-success/20 rounded-lg px-3 py-2">
            <CheckCircle2 className="w-3.5 h-3.5" />
            Constraints updated on-chain!
          </div>
        )}
        {txStatus === "error" && (
          <div className="flex items-center gap-2 text-xs text-danger bg-danger/10 border border-danger/20 rounded-lg px-3 py-2">
            <AlertCircle className="w-3.5 h-3.5" />
            {txError || "Transaction failed"}
          </div>
        )}

        {/* Save */}
        <button
          onClick={handleSave}
          disabled={saving}
          className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-btc rounded-lg text-sm font-semibold text-black hover:bg-btc-hover transition-all disabled:opacity-60"
        >
          {saving ? (
            <svg
              className="animate-spin h-4 w-4"
              viewBox="0 0 24 24"
              fill="none"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
          ) : (
            <Save className="w-4 h-4" />
          )}
          {saving ? "Saving…" : "Update Constraints"}
        </button>
      </div>
    </div>
  );
}
