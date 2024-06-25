"use client";
import { useAccount, useConnect, useDisconnect } from "@starknet-react/core";
import { useMemo } from "react";
import { Box, List, ListItem, Text, UnorderedList } from "@chakra-ui/react";

export default function About() {
  const { address } = useAccount();

  return (
    <>
   
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
      
    </>)
}
