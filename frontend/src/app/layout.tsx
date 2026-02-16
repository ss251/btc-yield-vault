import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { StarknetProvider } from "@/providers/StarknetProvider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "SatStack | BTC Yield Vault on Starknet",
  description: "Earn yield on your Bitcoin with SatStack - the premier BTC yield vault built on Starknet",
  keywords: ["Bitcoin", "BTC", "Starknet", "DeFi", "Yield", "Vault"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} font-sans antialiased bg-[#0D0D0D] text-white min-h-screen`}>
        <StarknetProvider>
          {children}
        </StarknetProvider>
      </body>
    </html>
  );
}
