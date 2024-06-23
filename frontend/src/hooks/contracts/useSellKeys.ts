import { CONTRACT_ADDRESS } from "@/constants/address";
import { useAccount, useNetwork } from "@starknet-react/core";
import { Account, AccountInterface, Call, CallData, RpcProvider, cairo } from "starknet";
import { prepareAndConnectContract } from "./useDataKeys";
import { TokenQuoteBuyKeys } from "@/types";

export const useSellKeys = () => {

    const account = useAccount();
    const chain = useNetwork()
    const chainId = chain?.chain?.id
    console.log("chainId", chainId)
    const provider = new RpcProvider({ nodeUrl: 'http://127.0.0.1:5050' });

    const handleSellKeys = async (account: AccountInterface, user_address: string, tokenQuote: TokenQuoteBuyKeys, amount: number, contractAddress?: string) => {
        if (!account) return;

        let addressContract = contractAddress ?? CONTRACT_ADDRESS.DEVNET.KEY
        console.log("addressContract", addressContract)
        // let asset = await prepareAndConnectContract(
        //     provider,
        //     tokenQuote?.token_address?.toString(),
        //     account
        // );

        let key_contract = await prepareAndConnectContract(
            provider,
            addressContract,
            account
        );

        const sellKeysParams = {
            user_address: user_address, // token address
            amount: cairo.uint256(amount), // amount int. Float need to be convert with bnToUint
        };

        let call = {
            contractAddress: addressContract,
            entrypoint: 'sell_keys',
            calldata: CallData.compile({
                user_address:sellKeysParams.user_address, amount:sellKeysParams.amount,
            }),
        }

        console.log("Call", call)
        let tx = await account?.execute([call], undefined, {})
        console.log("tx hash", tx.transaction_hash)
        let wait_tx = await account?.waitForTransaction(tx?.transaction_hash)

    };

    return { handleSellKeys }

}