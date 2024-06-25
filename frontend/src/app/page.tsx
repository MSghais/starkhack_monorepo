"use client";
import About from "@/components/About";
import AboutStarknet from "@/components/AboutStarknet";
import FormGasless from "@/components/FormGasless";
import KeysMarketplace from "@/components/KeysMarketplace";
import WalletBar from "@/components/WalletBar";
import { ModeToggle } from "@/components/button/ModeToggle";
import { Box, List, ListItem, Text, UnorderedList } from "@chakra-ui/react";
import { useAccount } from "@starknet-react/core";

export default function Home() {


  const account = useAccount()
  return (
    <main
      // className="
      // flex flex-col 
      // items-center justify-center min-h-screen 
      // gap-12 
      // text-left"
      className="
    flex flex-col 
    items-center justify-center min-h-screen 
    gap-12 
    text-left"
    >
      <About></About>
      <WalletBar />

      <Box>
        <KeysMarketplace></KeysMarketplace>

      </Box>
      {/* <AboutStarknet></AboutStarknet> */}
      <ModeToggle></ModeToggle>


    </main>
  );
}
