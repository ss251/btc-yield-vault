"use client";

import { ReactNode, useEffect, useState } from "react";
import { sepolia, mainnet } from "@starknet-react/chains";
import {
  StarknetConfig,
  publicProvider,
  argent,
  braavos,
  useInjectedConnectors,
} from "@starknet-react/core";

interface StarknetProviderProps {
  children: ReactNode;
}

function StarknetConfigWrapper({ children }: StarknetProviderProps) {
  const { connectors } = useInjectedConnectors({
    recommended: [argent(), braavos()],
    includeRecommended: "onlyIfNoConnectors",
    order: "random",
  });

  return (
    <StarknetConfig
      chains={[sepolia, mainnet]}
      provider={publicProvider()}
      connectors={connectors}
    >
      {children}
    </StarknetConfig>
  );
}

export function StarknetProvider({ children }: StarknetProviderProps) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return <>{children}</>;
  }

  return <StarknetConfigWrapper>{children}</StarknetConfigWrapper>;
}
