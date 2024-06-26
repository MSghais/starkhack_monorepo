import { FC, useCallback, useEffect, useState } from 'react';

import { Account, AccountInterface, Call, CallData, EstimateFeeResponse, cairo, stark, transaction, uint256 } from 'starknet';
import { Box, Button, useToast, Text, Divider, Card, Input } from '@chakra-ui/react';
import { KeysUser } from '@/types';
import { feltToAddress } from '@/helpers/format';
import { useBuyKeys } from '@/hooks/contracts/useBuyKeys';
import { useSellKeys } from '@/hooks/contracts/useSellKeys';
import { useAccount } from '@starknet-react/core';


const KeyCard = (key: KeysUser) => {
  const account = useAccount()
  const { handleBuyKeys } = useBuyKeys()
  const { handleSellKeys } = useSellKeys()
  const [amount, setAmount] = useState<number | undefined>()

  console.log("KeyCard key", key)


  const toast = useToast()
  const buyKeys = () => {
    console.log("Buy keys")
    if (!account) {
      return toast({
        title: "Connect you"
      })
    }
    if (!account?.account) {
      return toast({
        title: "Connect you"
      })
    }
    if (!amount) {
      return toast({
        title: "Enter amount to buy"
      })
    }
    handleBuyKeys(account.account,
      // key.owner
      feltToAddress(BigInt(key.owner))
      , key.token_quote, amount)
  }

  const sellKeys = () => {
    console.log("SEll keys")
    if (!account) {
      return toast({
        title: "Connect you"
      })
    }
    if (!account?.account) {
      return toast({
        title: "Connect you"
      })
    }
    if (!amount) {
      return toast({
        title: "Enter amount to sell"
      })
    }
    handleSellKeys(account.account,
      // key.owner
      feltToAddress(BigInt(key.owner))
      , key.token_quote, amount)
  }
  if (!key) {
    return <></>
  }

  return (

    <Card
      textAlign={"left"}
      maxW={{ base: "100%" }}
      minH={{ base: "150px" }}
      py={{ base: "0.5em" }}
      p={{ base: "1.5em", md: "1.5em" }}
      w={{ base: "100%", md: "330px", lg: "450px" }}
      maxWidth={{ lg: "750px" }}
      rounded={"1em"}
      overflow={"hidden"}
      justifyContent={"space-between"}
      border={"1px"}
      height={"100%"}

    >

      <Text>Total supply: {Number(key.total_supply)}</Text>
      <Text>Initial key price: {Number(key.initial_key_price) / 10 ** 18}</Text>
      <Text>Price: {Number(key.price) / 10 ** 18}</Text>

      <Box
        borderRadius={"3x"}
        shadow={"xl"}
        borderColor={"black"}
        border="3px"
        padding={"1em"}
      >
        <Text fontFamily={"monospace"} textAlign={"center"}>Token quote</Text>
        <Text>Asset: {feltToAddress(BigInt(key.token_quote.token_address))}</Text>
        <Text>Step increase linear: {Number(key.token_quote.step_increase_linear) / 10 ** 18}</Text>
      </Box>

      <Box>

        <Input
          // my='1em'
          my={{ base: "0.25em", md: "0.5em" }}
          py={{ base: "0.5em" }}
          onChange={(e) => {
            setAmount(Number(e.target.value))
          }}
          placeholder="Amount"
        ></Input>

        <Box display={"flex"} gap="1em">

          <Button onClick={buyKeys} bg={"green.200"} >Buy</Button>
          <Button onClick={sellKeys} bg={"red.200"}>Sell</Button>

        </Box>

      </Box>


    </Card>

  );
};

export default KeyCard;