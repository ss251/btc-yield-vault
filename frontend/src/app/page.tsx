"use client";

import dynamic from "next/dynamic";

const WalletConnect = dynamic(() => import("@/components/WalletConnect").then(m => m.WalletConnect), { ssr: false });
const VaultStats = dynamic(() => import("@/components/VaultStats").then(m => m.VaultStats), { ssr: false });
const VaultDeposit = dynamic(() => import("@/components/VaultDeposit").then(m => m.VaultDeposit), { ssr: false });
const VaultWithdraw = dynamic(() => import("@/components/VaultWithdraw").then(m => m.VaultWithdraw), { ssr: false });

export default function Home() {
  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-[#2A2A2A]">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#F7931A] flex items-center justify-center">
              <svg
                className="w-6 h-6 text-black"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M23.638 14.904c-1.602 6.43-8.113 10.34-14.542 8.736C2.67 22.05-1.244 15.525.362 9.105 1.962 2.67 8.475-1.243 14.9.358c6.43 1.605 10.342 8.115 8.738 14.546z" />
                <path
                  fill="#0D0D0D"
                  d="M14.314 9.703c.408-2.723-1.665-4.189-4.5-5.167l.92-3.684-2.243-.559-.896 3.587c-.59-.147-1.195-.285-1.797-.422l.902-3.613-2.242-.559-.92 3.683c-.488-.111-.967-.221-1.431-.337l.002-.01L.024 2.105l-.597 2.395s1.665.381 1.63.405c.909.227 1.073.828 1.046 1.305l-1.048 4.2c.063.016.144.039.234.075l-.238-.06-1.47 5.886c-.111.276-.393.69-1.029.533.023.033-1.631-.407-1.631-.407L-2.5 18.58l2.026.505c.377.095.746.194 1.11.287l-.93 3.73 2.24.559.92-3.686c.613.166 1.207.319 1.788.463l-.917 3.67 2.242.559.93-3.722c3.834.725 6.716.433 7.928-3.034.977-2.792-.048-4.404-2.067-5.456 1.47-.339 2.576-1.305 2.872-3.302zm-5.14 7.208c-.694 2.79-5.39 1.282-6.913.904l1.233-4.94c1.523.38 6.4 1.132 5.68 4.036zm.695-7.246c-.634 2.538-4.543 1.248-5.812.932l1.118-4.48c1.27.316 5.35.907 4.694 3.548z"
                />
              </svg>
            </div>
            <span className="text-2xl font-bold">
              Sat<span className="text-[#F7931A]">Stack</span>
            </span>
          </div>
          <WalletConnect />
        </div>
      </header>

      {/* Hero Section */}
      <section className="max-w-7xl mx-auto px-6 py-20">
        <div className="text-center mb-16">
          <h1 className="text-5xl md:text-7xl font-bold mb-6 tracking-tight">
            Maximize Your
            <br />
            <span className="text-[#F7931A]">Bitcoin Yield</span>
          </h1>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto leading-relaxed">
            Deposit your BTC into our secure vault on Starknet and earn
            competitive yields through optimized DeFi strategies.
          </p>
        </div>

        {/* Stats Section */}
        <VaultStats />

        {/* Deposit/Withdraw Section */}
        <div className="mt-12 grid grid-cols-1 md:grid-cols-2 gap-6">
          <VaultDeposit />
          <VaultWithdraw />
        </div>
      </section>

      {/* Features Section */}
      <section className="border-t border-[#2A2A2A] py-20">
        <div className="max-w-7xl mx-auto px-6">
          <h2 className="text-3xl font-bold text-center mb-12">
            Why <span className="text-[#F7931A]">SatStack</span>?
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="text-center p-8">
              <div className="w-16 h-16 rounded-2xl bg-[#1A1A1A] border border-[#2A2A2A] flex items-center justify-center mx-auto mb-6">
                <svg
                  className="w-8 h-8 text-[#F7931A]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-semibold mb-3">Secure</h3>
              <p className="text-gray-400">
                Built on Starknet with audited smart contracts and robust
                security measures
              </p>
            </div>
            <div className="text-center p-8">
              <div className="w-16 h-16 rounded-2xl bg-[#1A1A1A] border border-[#2A2A2A] flex items-center justify-center mx-auto mb-6">
                <svg
                  className="w-8 h-8 text-[#F7931A]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-semibold mb-3">High Yield</h3>
              <p className="text-gray-400">
                Optimized strategies to maximize returns while minimizing risk
              </p>
            </div>
            <div className="text-center p-8">
              <div className="w-16 h-16 rounded-2xl bg-[#1A1A1A] border border-[#2A2A2A] flex items-center justify-center mx-auto mb-6">
                <svg
                  className="w-8 h-8 text-[#F7931A]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-semibold mb-3">Fast</h3>
              <p className="text-gray-400">
                Leveraging Starknet&apos;s scalability for instant transactions
                and low fees
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-[#2A2A2A] py-8">
        <div className="max-w-7xl mx-auto px-6 text-center text-gray-500">
          <p>
            Built for RE&#123;DEFINE&#125; Hackathon •{" "}
            <span className="text-[#F7931A]">SatStack</span> © 2026
          </p>
        </div>
      </footer>
    </div>
  );
}
