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
import { AccountInterface, Call, CallData, EstimateFeeResponse, cairo, stark, transaction } from 'starknet';
import WalletBar from './WalletBar';
import { Button, useToast } from '@chakra-ui/react';
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

const FormGasless: FC = () => {
  const { account, isConnected } = useAccount();
  const { address } = useAccount();
  const { chain } = useNetwork();
  const { provider } = useProvider();
  const [loading, setLoading] = useState(false);
  const [tx, setTx] = useState<string>();
  const [paymasterRewards, setPaymasterRewards] = useState<PaymasterReward[]>([]);
  const [calls, setCalls] = useState(JSON.stringify(initialValue, null, 2));
  const [gasTokenPrices, setGasTokenPrices] = useState<GasTokenPrice[]>([]);
  const [gasTokenPrice, setGasTokenPrice] = useState<GasTokenPrice>();
  const [maxGasTokenAmount, setMaxGasTokenAmount] = useState<bigint>();
  const [gaslessCompatibility, setGaslessCompatibility] = useState<GaslessCompatibility>();
  const [errorMessage, setErrorMessage] = useState<string>();
  const toast = useToast()
  useEffect(() => {
    if (!account) return;
    fetchAccountCompatibility(account.address, options).then(setGaslessCompatibility);
    fetchAccountsRewards(account.address, { ...options, protocol: 'gasless-sdk' }).then(setPaymasterRewards);
  }, [account]);

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

  // Retrieve estimated gas fees
  useEffect(() => {
    if (!account || !gasTokenPrice || !gaslessCompatibility) return;
    setErrorMessage(undefined);
    let call = {
      contractAddress: "0x00148a15f9fbf4c015b927bf88608fbafb6d149abdd5ef5b3e3b",
      entrypoint: 'transfer',
      calldata: CallData.compile({
        recipient: account?.address,
        amount: cairo.uint256(1),
      }),
    }
    console.log("call", call)

    if (!isValidJSON(calls)) {
      toast({ title: 'No calls' })
      setErrorMessage('Invalid calls');
      return;
    }


    // const parsedCalls: Call[] = JSON.parse(calls);

    // parsedCalls.push(call)
    // estimateCalls(account, parsedCalls).then((fees) => {
    //   console.log("parsedCalls",parsedCalls)

    //   const estimatedGasFeesInGasToken = getGasFeesInGasToken(
    //     BigInt(fees.overall_fee),
    //     gasTokenPrice,
    //     BigInt(fees.gas_price!),
    //     BigInt(fees.data_gas_price ?? '0x1'),
    //     gaslessCompatibility.gasConsumedOverhead,
    //     gaslessCompatibility.dataGasConsumedOverhead,
    //   );
    //   console.log("estimatedGasFeesInGasToken",estimatedGasFeesInGasToken)
    //   setMaxGasTokenAmount(estimatedGasFeesInGasToken * BigInt(2));
    // });
  }, [calls, account, gasTokenPrice, gaslessCompatibility, estimateCalls]);

  const onClickExecute = async () => {
    if (!account) return;
    setLoading(true);
    setTx(undefined);
    if (!gasTokenPrice) {
      toast({ title: 'No gas token price' })
    }
    let call = {
      contractAddress: "0x00148a15f9fbf4c015b927bf88608fbafb6d149abdd5ef5b3e3b",
      entrypoint: 'transfer',
      calldata: CallData.compile({
        recipient: account?.address,
        amount: cairo.uint256(1),
      }),
    }

    const parsedCalls: Call[] = JSON.parse(calls);

    parsedCalls.push(call)
    console.log("parsedCalls", parsedCalls)
    console.log("gasTokenPrice", gasTokenPrice)
    console.log("gaslessCompatibility", gaslessCompatibility)
    fetchAccountCompatibility(account.address, options).then(setGaslessCompatibility);
    let compatibility= await fetchAccountCompatibility(account.address, options)

    console.log("compatibility",compatibility)

    setGaslessCompatibility(compatibility)
    if (!account || !gasTokenPrice || !compatibility) return;

    estimateCalls(account, parsedCalls).then((fees) => {

      const estimatedGasFeesInGasToken = getGasFeesInGasToken(
        BigInt(fees.overall_fee),
        gasTokenPrice,
        BigInt(fees.gas_price!),
        BigInt(fees.data_gas_price ?? '0x1'),
        compatibility.gasConsumedOverhead,
        compatibility.dataGasConsumedOverhead,
      );
      console.log("estimatedGasFeesInGasToken", estimatedGasFeesInGasToken)
      setMaxGasTokenAmount(estimatedGasFeesInGasToken * BigInt(2));
    });
    // let call= {
    //   contractAddress: "0x00148a15f9fbf4c015b927bf88608fbafb6d149abdd5ef5b3e3b",
    //   entrypoint: 'transfer',
    //   calldata: CallData.compile({
    //     recipient: account?.address,
    //     amount: cairo.uint256(1),
    //   }),
    // }

    return executeCalls(
      account,
      JSON.parse(calls),
      {
        gasTokenAddress: gasTokenPrice?.tokenAddress,
        maxGasTokenAmount,
      },
      options,
    )
      .then((response) => {
        setTx(response.transactionHash);
        setLoading(false);
      })
      .catch((error) => {
        setLoading(false);
        console.error(error);
      });
  };

  useEffect(() => {
    fetchGasTokenPrices(options).then(setGasTokenPrices);
  }, []);

  if (!isConnected) {
    return <WalletBar />;
  }

  // if (chain !== undefined && chain.name !== 'Starknet Sepolia Testnet') {
  //   return <p>Please connect with a sepolia account</p>;
  // }

  return (
    <div>
      <p>Connected with account: {address}</p>
      <p>Execute tx:</p>
      {/* <textarea
        value={calls}
        onChange={(e) => setCalls(e.target.value)}
        style={{ minHeight: '500px', minWidth: '1000px' }}
      /> */}
      <div>
        <p>
          <strong>Paymaster rewards</strong>
        </p>
        {paymasterRewards.length == 0 ? <p>No reward</p> : <p>{JSON.stringify(paymasterRewards)}</p>}
      </div>
      <div>
        <p>
          <strong>Gas tokens</strong>
        </p>
        {paymasterRewards.length > 0 ? (
          <p>No gas fees to pay. You have a reward.</p>
        ) : (
          gasTokenPrices.map((price) => (
            <button
              disabled={price.tokenAddress === gasTokenPrice?.tokenAddress}
              onClick={() => setGasTokenPrice(price)}
            >
              {price.tokenAddress}
            </button>
          ))
        )}
      </div>
      {tx && (
        <a href={`https://sepolia.voyager.online/tx/${tx}`} target={'_blank'} rel='noreferrer'>
          Success:{tx}
        </a>
      )}
      {errorMessage && <p style={{ color: 'red' }}>{errorMessage}</p>}
      {paymasterRewards.length == 0 && !gasTokenPrice && <p>Select a gas token</p>}
      {maxGasTokenAmount !== undefined && gasTokenPrice !== undefined && (
        <p>Max gas fees in gas token: {formatUnits(maxGasTokenAmount, gasTokenPrice.decimals)}</p>
      )}
      <div>
        {account && (
          <Button
            // disabled={!isValidJSON(calls) || loading || (!gasTokenPrice && paymasterRewards.length == 0)}
            onClick={onClickExecute}
          >
            {loading ? 'Loading' : 'Execute'}
          </Button>
        )}
      </div>
    </div>
  );
};

export default FormGasless;