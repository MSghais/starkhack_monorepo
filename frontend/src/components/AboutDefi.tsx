"use client";
import { useAccount, useConnect, useDisconnect } from "@starknet-react/core";
import { useMemo } from "react";
import { Box, List, ListItem, Text, UnorderedList } from "@chakra-ui/react";

export default function AboutDefi() {
  const { address } = useAccount();

  return (
    <>
      <Box>
        <Text>
          Mint jBTC and jUSD.
        </Text>
        <Box fontFamily={"monospace"}>
          <Text>
            Price can have different type.
          </Text>
          <UnorderedList>
            <ListItem>
              Bitcoin everywhere.

            </ListItem>
            <ListItem>
              BTC Fi activated
            </ListItem>

            <ListItem>
             Fast payments
            </ListItem>

          </UnorderedList>
        </Box>

      </Box>

    </>)
}
