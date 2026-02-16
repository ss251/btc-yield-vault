"use client";

import dynamic from "next/dynamic";
import { useXverseWallet } from "@/providers/XverseProvider";
import { Bot, Shield, Cpu, ArrowRight, Github } from "lucide-react";

const WalletConnect = dynamic(() => import("@/components/WalletConnect").then((m) => m.WalletConnect), { ssr: false });
const PortfolioPanel = dynamic(() => import("@/components/PortfolioPanel").then((m) => m.PortfolioPanel), { ssr: false });
const AgentStatus = dynamic(() => import("@/components/AgentStatus").then((m) => m.AgentStatus), { ssr: false });
const ActionHistory = dynamic(() => import("@/components/ActionHistory").then((m) => m.ActionHistory), { ssr: false });
const ConstraintsEditor = dynamic(() => import("@/components/ConstraintsEditor").then((m) => m.ConstraintsEditor), { ssr: false });
const ActivityFeed = dynamic(() => import("@/components/ActivityFeed").then((m) => m.ActivityFeed), { ssr: false });

export default function Home() {
  const { connected } = useXverseWallet();

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="sticky top-0 z-50 backdrop-blur-xl bg-dark-bg/80 border-b border-dark-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-btc flex items-center justify-center">
              <Bot className="w-4.5 h-4.5 text-black" />
            </div>
            <span className="text-lg font-bold tracking-tight">
              ZK<span className="text-btc">Agent</span>
            </span>
          </div>
          <WalletConnect />
        </div>
      </header>

      {!connected ? <HeroSection /> : <Dashboard />}

      {/* Footer */}
      <footer className="border-t border-dark-border py-6 mt-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 text-center text-xs text-gray-600">
          Built for RE&#123;DEFINE&#125; Hackathon · ZK-Constrained Autonomous Bitcoin Agent
        </div>
      </footer>
    </div>
  );
}

function HeroSection() {
  const { connect, connecting } = useXverseWallet();

  return (
    <section className="max-w-4xl mx-auto px-4 sm:px-6 pt-24 pb-20">
      <div className="text-center">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-btc/10 border border-btc/20 text-btc text-xs font-medium mb-8">
          <Shield className="w-3 h-3" />
          ZK-Proven on Starknet
        </div>

        <h1 className="text-4xl sm:text-6xl md:text-7xl font-bold tracking-tight mb-6 leading-[1.1]">
          ZK-Constrained
          <br />
          <span className="text-btc">Bitcoin Agent</span>
        </h1>

        <p className="text-lg text-gray-400 max-w-xl mx-auto mb-10 leading-relaxed">
          AI manages your BTC autonomously. Every decision is constrained by your rules
          and <span className="text-gray-300">ZK-proven on Starknet</span> — verifiable, trustless, yours.
        </p>

        <button
          onClick={connect}
          disabled={connecting}
          className="inline-flex items-center gap-2 px-8 py-4 bg-btc rounded-xl font-semibold text-black text-base hover:bg-btc-hover transition-all hover:shadow-[0_0_40px_rgba(247,147,26,0.3)] animate-glow disabled:opacity-60"
        >
          {connecting ? "Connecting…" : "Connect Xverse Wallet"}
          <ArrowRight className="w-4 h-4" />
        </button>

        {/* Feature pills */}
        <div className="flex flex-wrap justify-center gap-3 mt-16">
          {[
            { icon: <Bot className="w-3.5 h-3.5" />, text: "Autonomous Agent" },
            { icon: <Shield className="w-3.5 h-3.5" />, text: "ZK Proofs" },
            { icon: <Cpu className="w-3.5 h-3.5" />, text: "On-chain Constraints" },
          ].map((f) => (
            <div key={f.text} className="flex items-center gap-2 px-4 py-2 bg-dark-card border border-dark-border rounded-xl text-sm text-gray-400">
              <span className="text-btc">{f.icon}</span>
              {f.text}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Dashboard() {
  return (
    <section className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
      {/* Top row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-5 stagger-children">
        <PortfolioPanel />
        <AgentStatus />
      </div>

      {/* Middle row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5 mb-5">
        <div className="lg:col-span-2">
          <ActionHistory />
        </div>
        <ConstraintsEditor />
      </div>

      {/* Activity Feed */}
      <ActivityFeed />
    </section>
  );
}
