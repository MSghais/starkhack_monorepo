import KeysMarketplace from "@/components/KeysMarketplace";
import { CONTRACT_ADDRESS } from "@/constants/address";
import { useAccount, useNetwork } from "@starknet-react/core";
import { Account, AccountInterface, Call, CallData, RpcProvider, cairo } from "starknet";
import { prepareAndConnectContract } from "./useDataKeys";
import { TokenQuoteBuyKeys } from "@/types";

export const useBuyKeys = () => {

    const account = useAccount();
    const chain = useNetwork()
    const chainId = chain?.chain?.id
    console.log("chainId", chainId)
    const provider = new RpcProvider({ nodeUrl: 'http://127.0.0.1:5050' });

    const handleBuyKeys = async (account: AccountInterface, user_address: string, tokenQuote: TokenQuoteBuyKeys, amount: number, contractAddress?: string) => {
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


        const buyKeysParams = {
            user_address: user_address, // token address
            amount: cairo.uint256(amount), // amount int. Float need to be convert with bnToUint
        };


        // let amountToPaid = await key_contract.get_amount_to_paid(account?.address, amount,);

        // console.log("amount to paid", amountToPaid)

        // let txApprove = await asset.approve(
        //     addressContract,
        //     cairo.uint256(amountToPaid), // change for decimals float => uint256.bnToUint256("0x"+alicePublicKey)
        // )

        let call = {
            contractAddress: addressContract,
            entrypoint: 'buy_keys',
            calldata: CallData.compile({
                user_address:buyKeysParams.user_address, amount:buyKeysParams.amount,
            }),
            // calldata: [buyKeysParams.user_address, buyKeysParams.amount]
        }


        console.log("Call", call)

        let tx = await account?.execute([call], undefined, {})
        console.log("tx hash", tx.transaction_hash)
        let wait_tx = await account?.waitForTransaction(tx?.transaction_hash)


    };


    return { handleBuyKeys }

}