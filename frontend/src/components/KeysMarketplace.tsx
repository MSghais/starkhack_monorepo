import { FC, useCallback, useEffect, useState } from 'react';
import {
  GaslessOptions,
  SEPOLIA_BASE_URL,
} from '@avnu/gasless-sdk';
import { useAccount, useNetwork, useProvider } from '@starknet-react/core';
import { Account, AccountInterface, Call, CallData, EstimateFeeResponse, cairo, stark, transaction, uint256 } from 'starknet';
import { Box, Button, useToast, Text, Divider, Card } from '@chakra-ui/react';
import { useInstantiateKeys } from '@/hooks/contracts/useInstantiateKeys';
import { useDataKeys } from '@/hooks/contracts/useDataKeys';
import { KeysUser } from '@/types';
import { Fraction } from '@uniswap/sdk-core';
import { feltToAddress } from '@/helpers/format';
import KeyCard from './card/KeyCard';

const isValidJSON = (str: string): boolean => {
  try {
    JSON.parse(str);
    return true;
  } catch (e) {
    return false;
  }
};

const KeysMarketplace: FC = () => {
  const { account, isConnected } = useAccount();
  const [loading, setLoading] = useState(false);
  const [tx, setTx] = useState<string>();
  const [errorMessage, setErrorMessage] = useState<string>();
  const [keys, setKeys] = useState<any[]>([]);
  const toast = useToast()
  const { handleInstantiateKeys } = useInstantiateKeys()

  const { getAllKeys } = useDataKeys()
  console.log("keys", keys)

  const getKeys = async () => {
    let allKeys = await getAllKeys()

    console.log("allKeys", allKeys)
    setKeys(allKeys)
  }
  useEffect(() => {

    getKeys()
  }, [])
  const instantiateKeys = async () => {

    toast({ title: "Instantiate your keys" })
    if (account) {
      await handleInstantiateKeys(account)
    }
  }

  return (
    <Box>

      {tx && (
        <a href={`https://sepolia.voyager.online/tx/${tx}`} target={'_blank'} rel='noreferrer'>
          Success:{tx}
        </a>
      )}
      {errorMessage && <p style={{ color: 'red' }}>{errorMessage}</p>}



      <Button onClick={() => {
        getKeys()
      }}>Refresh</Button>
      <div>
        {account && (
          <Button
            borderRadius={{ base: "5px" }}
            padding={{ base: "5px" }}
            margin={{ base: "5px" }}
            bg="green.700"
            onClick={instantiateKeys}
          >
            {loading ? 'Loading' : 'Instantiate keys'}
          </Button>
        )}
      </div>


      <Box 
      display={"grid"}
        gap={{ md: "1em" }}
        gridTemplateColumns={{
          base: "repeat(1,1fr)"
          , md: "repeat(3,1fr)"
        }}
      >

        {keys.length > 0 && keys.map((k, i) => {
          let key_owner = feltToAddress(BigInt(k.owner))

          // Check null value 
          if (
            // cairo.uint256(k.total_supply) == cairo.uint256(0)|| 
            key_owner.length < 64
          ) {
            return <>
            </>
          }
          return (
            <>
              <KeyCard {...k}></KeyCard>
            </>

          )


        })}

      </Box>



    </Box>
  );
};

export default KeysMarketplace;