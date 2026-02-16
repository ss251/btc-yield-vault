"use client";

import { useXverseWallet } from "@/providers/XverseProvider";
import { Wallet, LogOut, Copy, Check } from "lucide-react";
import { useState } from "react";

export function WalletConnect() {
  const { connected, connecting, btcAddress, starknetAddress, connect, disconnect } = useXverseWallet();
  const [copied, setCopied] = useState(false);

  const shorten = (addr: string) => `${addr.slice(0, 6)}…${addr.slice(-4)}`;

  const copyAddress = () => {
    if (btcAddress) {
      navigator.clipboard.writeText(btcAddress);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  if (connected && btcAddress) {
    return (
      <div className="flex items-center gap-2">
        <button
          onClick={copyAddress}
          className="hidden sm:flex items-center gap-1.5 px-3 py-2 bg-dark-surface border border-dark-border rounded-lg text-xs text-gray-400 font-mono hover:border-dark-border-hover transition-colors"
        >
          <span className="text-btc">₿</span> {shorten(btcAddress)}
          {copied ? <Check className="w-3 h-3 text-success" /> : <Copy className="w-3 h-3" />}
        </button>
        {starknetAddress && (
          <span className="hidden md:flex items-center gap-1.5 px-3 py-2 bg-dark-surface border border-dark-border rounded-lg text-xs text-gray-400 font-mono">
            <span className="text-purple-400">◈</span> {shorten(starknetAddress)}
          </span>
        )}
        <button
          onClick={disconnect}
          className="p-2 bg-dark-surface border border-dark-border rounded-lg text-gray-400 hover:text-danger hover:border-danger/30 transition-all"
          title="Disconnect"
        >
          <LogOut className="w-4 h-4" />
        </button>
      </div>
    );
  }

  return (
    <button
      onClick={connect}
      disabled={connecting}
      className="flex items-center gap-2 px-5 py-2.5 bg-btc rounded-lg font-semibold text-black text-sm hover:bg-btc-hover transition-all hover:shadow-[0_0_30px_rgba(247,147,26,0.3)] disabled:opacity-60"
    >
      {connecting ? (
        <>
          <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          Connecting…
        </>
      ) : (
        <>
          <Wallet className="w-4 h-4" />
          Connect Wallet
        </>
      )}
    </button>
  );
}
