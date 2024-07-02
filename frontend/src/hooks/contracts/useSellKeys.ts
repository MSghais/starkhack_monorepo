import { CONTRACT_ADDRESS } from "@/constants/address";
import { useAccount, useNetwork, useProvider } from "@starknet-react/core";
import { Account, AccountInterface, Call, CallData, RpcProvider, cairo, uint256 } from "starknet";
import { prepareAndConnectContract } from "./useDataKeys";
import { TokenQuoteBuyKeys } from "@/types";
import { formatFloatToUint256 } from "@/helpers/format";

export const useSellKeys = () => {
    const account = useAccount();
    const chain = useNetwork()
    const rpcProvider = useProvider()
    const chainId = chain?.chain?.id
    // const provider = rpcProvider?.provider ?? new RpcProvider();
    const provider = rpcProvider?.provider ?? new RpcProvider();
    
    const handleSellKeys = async (account: AccountInterface, user_address: string, amount: number, contractAddress?: string, tokenQuote?: TokenQuoteBuyKeys, ) => {
        if (!account) return;
        let addressContract = CONTRACT_ADDRESS.SEPOLIA.KEY

        // let addressContract = contractAddress ?? CONTRACT_ADDRESS.SEPOLIA.KEY
        console.log("addressContract", addressContract)

        // let key_contract = await prepareAndConnectContract(
        //     provider,
        //     addressContract,
        //     account
        // );

        let amountUint256 = formatFloatToUint256(amount);
        amountUint256 = uint256.bnToUint256(BigInt("0x"+amount))
        
        const sellKeysParams = {
            user_address: user_address, // token address
            amount: amountUint256
            // amount: cairo.uint256(amount), // amount int. Float need to be convert with bnToUint
        };
        console.log("sellKeysParams", sellKeysParams)


        let call = {
            contractAddress: addressContract,
            entrypoint: 'sell_keys',
            calldata: CallData.compile({
                user_address:sellKeysParams.user_address, 
                amount:sellKeysParams.amount,
            }),
        }

        console.log("Call", call)
        let tx = await account?.execute([call], undefined, {})
        console.log("tx hash", tx.transaction_hash)
        let wait_tx = await account?.waitForTransaction(tx?.transaction_hash)

    };

    return { handleSellKeys }

}