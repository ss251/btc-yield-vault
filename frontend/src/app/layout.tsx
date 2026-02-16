import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { XverseProvider } from "@/providers/XverseProvider";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "ZK-Constrained Bitcoin Agent",
  description: "AI manages your BTC. Every decision ZK-proven on Starknet.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} font-sans antialiased bg-dark-bg text-white min-h-screen`}>
        <XverseProvider>{children}</XverseProvider>
      </body>
    </html>
  );
}
