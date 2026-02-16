"use client";

import { createContext, useContext, useState, useCallback, ReactNode, useEffect } from "react";

interface XverseAddress {
  address: string;
  publicKey: string;
  purpose: string;
  addressType?: string;
}

interface XverseWalletState {
  connected: boolean;
  connecting: boolean;
  addresses: XverseAddress[];
  btcAddress: string | null;
  starknetAddress: string | null;
  connect: () => Promise<void>;
  disconnect: () => void;
}

const XverseContext = createContext<XverseWalletState>({
  connected: false,
  connecting: false,
  addresses: [],
  btcAddress: null,
  starknetAddress: null,
  connect: async () => {},
  disconnect: () => {},
});

export const useXverseWallet = () => useContext(XverseContext);

const STORAGE_KEY = "xverse_connected";

export function XverseProvider({ children }: { children: ReactNode }) {
  const [connected, setConnected] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [addresses, setAddresses] = useState<XverseAddress[]>([]);

  const btcAddress = addresses.find((a) => a.purpose === "payment")?.address ?? null;
  const starknetAddress = addresses.find((a) => a.purpose === "starknet")?.address ?? null;

  const connect = useCallback(async () => {
    setConnecting(true);
    try {
      // Dynamic import for Next.js SSR compatibility
      // See: https://docs.xverse.app/sats-connect/guides/next.js-support
      const { request, AddressPurpose } = await import("sats-connect");

      const response = await request("wallet_connect", {
        addresses: [AddressPurpose.Payment, AddressPurpose.Starknet],
        message: "Connect to SatStack — BTC Yield Vault on Starknet",
      });

      if (response.status === "success") {
        const addrs = response.result.addresses as XverseAddress[];
        setAddresses(addrs);
        setConnected(true);
        try { sessionStorage.setItem(STORAGE_KEY, "1"); } catch {}
      }
    } catch (err) {
      console.error("Xverse connect failed:", err);
    } finally {
      setConnecting(false);
    }
  }, []);

  const disconnect = useCallback(() => {
    setAddresses([]);
    setConnected(false);
    try { sessionStorage.removeItem(STORAGE_KEY); } catch {}
  }, []);

  // Auto-reconnect on mount if previously connected
  useEffect(() => {
    try {
      if (sessionStorage.getItem(STORAGE_KEY) === "1") {
        connect();
      }
    } catch {}
  }, [connect]);

  return (
    <XverseContext.Provider
      value={{ connected, connecting, addresses, btcAddress, starknetAddress, connect, disconnect }}
    >
      {children}
    </XverseContext.Provider>
  );
}
