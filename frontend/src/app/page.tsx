"use client";
import AboutStarknet from "@/components/AboutStarknet";
import FormGasless from "@/components/FormGasless";
import KeysMarketplace from "@/components/KeysMarketplace";
import WalletBar from "@/components/WalletBar";
import { Box } from "@chakra-ui/react";
import { useAccount } from "@starknet-react/core";

export default function Home() {


  const account = useAccount()
  return (
    <main className="flex flex-col items-center justify-center min-h-screen gap-12">
      <WalletBar />


      <Box>
        <KeysMarketplace></KeysMarketplace>


      </Box>
      <AboutStarknet></AboutStarknet>
      {/* <FormGasless></FormGasless> */}

    </main>
  );
}
