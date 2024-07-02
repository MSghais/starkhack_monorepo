import { FC, useCallback, useEffect, useState } from 'react';
import {
  GaslessOptions,
  SEPOLIA_BASE_URL,
} from '@avnu/gasless-sdk';
import { useAccount, useNetwork, useProvider } from '@starknet-react/core';
import { Account, AccountInterface, Call, CallData, EstimateFeeResponse, cairo, stark, transaction, uint256 } from 'starknet';
import { Box, Button, useToast, Text, Divider, Card } from '@chakra-ui/react';

import { feltToAddress } from '@/helpers/format';
import KeyCard from './card/KeyCard';

const DefiView: FC = () => {
  const { account, isConnected } = useAccount();
  const [loading, setLoading] = useState(false);
  const [tx, setTx] = useState<string>();
  const [errorMessage, setErrorMessage] = useState<string>();
  const [keys, setKeys] = useState<any[]>([]);
  const toast = useToast()

  console.log("keys", keys)

  return (
    <Box>

      {tx && (
        <a href={`https://sepolia.voyager.online/tx/${tx}`} target={'_blank'} rel='noreferrer'>
          Success:{tx}
        </a>
      )}
      {errorMessage && <p style={{ color: 'red' }}>{errorMessage}</p>}

      <Text>Mint the jBTC and jUSD tokens.</Text>
      <Text>Vault for DeFi strategies.</Text>


      <Box
        display={"grid"}
        gap={{ md: "1em" }}
        gridTemplateColumns={{
          base: "repeat(1,1fr)"
          , md: "repeat(3,1fr)"
        }}
      >

      </Box>



    </Box>
  );
};

export default DefiView;