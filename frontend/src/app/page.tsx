"use client";
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
      <Box>
        <Text>Joyboy for Fun.</Text>
        <Text>Keys marketplace for your Starknet account Key. </Text>
        <Text>
          Users can buy and sell your keys. You get % of the buy and sell for your keys.
        </Text>
        <Box fontFamily={"monospace"}>
          <Text>
            Instante your keys for your Profile.
          </Text>

          <Text>
            Price can have different type.
          </Text>
          <UnorderedList>
            <ListItem>
              Linear is firstly implemented.

            </ListItem>
            <ListItem>
              Scoring with Nostr SocialFi

            </ListItem>
            <ListItem>
              Fair launch

            </ListItem>
            <ListItem>
          Limited supply

            </ListItem>


          </UnorderedList>
        </Box>

      </Box>
      <WalletBar />

      <Box>
        <KeysMarketplace></KeysMarketplace>

      </Box>
      {/* <AboutStarknet></AboutStarknet> */}
      <ModeToggle></ModeToggle>


    </main>
  );
}
