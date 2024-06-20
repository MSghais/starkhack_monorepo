"use client";
import AboutStarknet from "@/components/AboutStarknet";
import FormGasless from "@/components/FormGasless";
import WalletBar from "@/components/WalletBar";

export default function Home() {
  return (
    <main className="flex flex-col items-center justify-center min-h-screen gap-12">
      <WalletBar />
      <AboutStarknet></AboutStarknet>
      <FormGasless></FormGasless>

    </main>
  );
}
