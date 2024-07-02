"use client";
import About from "@/components/About";
import AboutStarknet from "@/components/AboutStarknet";
import DefiView from "@/components/DefiView";
import FormGasless from "@/components/FormGasless";
import KeysMarketplace from "@/components/KeysMarketplace";
import WalletBar from "@/components/WalletBar";
import { ModeToggle } from "@/components/button/ModeToggle";
import { Box, List, ListItem, Tab, TabList, TabPanel, TabPanels, Tabs, Text, UnorderedList } from "@chakra-ui/react";
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
      <WalletBar />


      <Tabs>
        <TabList>
          <Tab>Keys</Tab>
          <Tab>DeFi</Tab>
        </TabList>
        <TabPanels>
          <TabPanel>
            <Box>
              <KeysMarketplace></KeysMarketplace>
              <About></About>

            </Box>
          </TabPanel>
          <TabPanel>
            <Box>
            <DefiView></DefiView>

            </Box>

          </TabPanel>

        </TabPanels>
      </Tabs>


      {/* <AboutStarknet></AboutStarknet> */}
      <ModeToggle></ModeToggle>




    </main>
  );
}
