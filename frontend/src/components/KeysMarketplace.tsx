import { FC, useCallback, useEffect, useState } from 'react';
import {
  executeCalls,
  fetchAccountCompatibility,
  fetchAccountsRewards,
  fetchGasTokenPrices,
  GaslessCompatibility,
  GaslessOptions,
  GasTokenPrice,
  getGasFeesInGasToken,
  PaymasterReward,
  SEPOLIA_BASE_URL,
} from '@avnu/gasless-sdk';
import { useAccount, useNetwork, useProvider } from '@starknet-react/core';
import { formatUnits } from 'ethers';
import { Account, AccountInterface, Call, CallData, EstimateFeeResponse, cairo, stark, transaction } from 'starknet';
import WalletBar from './WalletBar';
import { Box, Button, useToast } from '@chakra-ui/react';
import { useInstantiateKeys } from '@/hooks/contracts/useInstantiateKeys';
// import Connect from './Connect';

const options: GaslessOptions = { baseUrl: SEPOLIA_BASE_URL };
const initialValue: Call[] = [
  {
    entrypoint: 'approve',
    contractAddress: '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
    calldata: ['0x0498E484Da80A8895c77DcaD5362aE483758050F22a92aF29A385459b0365BFE', '0xf', '0x0'],
  },
];
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
  const { address } = useAccount();
  const { chain } = useNetwork();
  const { provider } = useProvider();
  const [loading, setLoading] = useState(false);
  const [tx, setTx] = useState<string>();
  const [calls, setCalls] = useState(JSON.stringify(initialValue, null, 2));
  const [maxGasTokenAmount, setMaxGasTokenAmount] = useState<bigint>();
  const [errorMessage, setErrorMessage] = useState<string>();
  const toast = useToast()
  const {handleInstantiateKeys} = useInstantiateKeys()

  // The account.estimateInvokeFee doesn't work...
  const estimateCalls = useCallback(
    async (account: AccountInterface, calls: Call[]): Promise<EstimateFeeResponse> => {
      const contractVersion = await provider.getContractVersion(account.address);
      const nonce = await provider.getNonceForAddress(account.address);
      const details = stark.v3Details({ skipValidate: true });
      const invocation = {
        ...details,
        contractAddress: account.address,
        calldata: transaction.getExecuteCalldata(calls, contractVersion.cairo),
        signature: [],
      };
      return provider.getInvokeEstimateFee({ ...invocation }, { ...details, nonce }, 'pending', true);
    },
    [provider],
  );

  // if (!isConnected) {
  //   return <WalletBar />;
  // }

  // if (chain !== undefined && chain.name !== 'Starknet Sepolia Testnet') {
  //   return <p>Please connect with a sepolia account</p>;
  // }

  const instantiateKeys = async () => {

    toast({title:"Instantiate your keys"})
    if(account) {
      await handleInstantiateKeys(account)

    }

  }

  return (
    <Box>
      <p>Connected with account: {address}</p>
 
      {tx && (
        <a href={`https://sepolia.voyager.online/tx/${tx}`} target={'_blank'} rel='noreferrer'>
          Success:{tx}
        </a>
      )}
      {errorMessage && <p style={{ color: 'red' }}>{errorMessage}</p>}
     
      <div>
        {account && (
          <Button
            onClick={instantiateKeys}
          >
            {loading ? 'Loading' : 'Instantiate keys'}
          </Button>
        )}
      </div>
    </Box>
  );
};

export default KeysMarketplace;