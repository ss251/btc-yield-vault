"use client";

import { useConnect, useDisconnect, useAccount } from "@starknet-react/core";
import { useState, useEffect } from "react";

export function WalletConnect() {
  const [mounted, setMounted] = useState(false);
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { address, status } = useAccount();
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const shortenAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  if (!mounted) {
    return (
      <button className="px-6 py-3 bg-[#F7931A] rounded-xl font-semibold text-black opacity-50">
        Connect Wallet
      </button>
    );
  }

  if (status === "connected" && address) {
    return (
      <button
        onClick={() => disconnect()}
        className="group relative px-6 py-3 bg-[#1A1A1A] border border-[#2A2A2A] rounded-xl font-medium text-white hover:border-[#F7931A] transition-all duration-300"
      >
        <span className="group-hover:opacity-0 transition-opacity">
          {shortenAddress(address)}
        </span>
        <span className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity text-[#F7931A]">
          Disconnect
        </span>
      </button>
    );
  }

  return (
    <>
      <button
        onClick={() => setShowModal(true)}
        className="px-6 py-3 bg-[#F7931A] rounded-xl font-semibold text-black hover:bg-[#E8850F] transition-all duration-300 hover:shadow-[0_0_30px_rgba(247,147,26,0.3)]"
      >
        Connect Wallet
      </button>

      {showModal && (
        <div
          className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50"
          onClick={() => setShowModal(false)}
        >
          <div
            className="bg-[#1A1A1A] border border-[#2A2A2A] rounded-2xl p-8 max-w-md w-full mx-4"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-2xl font-bold text-white mb-6">
              Connect Wallet
            </h2>
            <div className="space-y-3">
              {connectors.map((connector) => (
                <button
                  key={connector.id}
                  onClick={() => {
                    connect({ connector });
                    setShowModal(false);
                  }}
                  className="w-full px-6 py-4 bg-[#0D0D0D] border border-[#2A2A2A] rounded-xl font-medium text-white hover:border-[#F7931A] hover:bg-[#1A1A1A] transition-all duration-300 flex items-center gap-4"
                >
                  <div className="w-10 h-10 rounded-lg bg-[#2A2A2A] flex items-center justify-center">
                    <span className="text-[#F7931A] text-lg">
                      {connector.id[0].toUpperCase()}
                    </span>
                  </div>
                  <span className="capitalize">{connector.id}</span>
                </button>
              ))}
            </div>
            <button
              onClick={() => setShowModal(false)}
              className="mt-6 w-full px-6 py-3 text-gray-400 hover:text-white transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </>
  );
}
