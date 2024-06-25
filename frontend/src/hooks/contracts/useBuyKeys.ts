import KeysMarketplace from "@/components/KeysMarketplace";
import { CONTRACT_ADDRESS } from "@/constants/address";
import { useAccount, useNetwork, useProvider } from "@starknet-react/core";
import { Account, AccountInterface, Call, CallData, RpcProvider, cairo, uint256 } from "starknet";
import { prepareAndConnectContract } from "./useDataKeys";
import { TokenQuoteBuyKeys } from "@/types";
import { feltToAddress, formatFloatToUint256 } from "@/helpers/format";

export const useBuyKeys = () => {

    const account = useAccount();
    const chain = useNetwork()
    // const chainId = chain?.chain?.id
    // console.log("chainId", chainId)
    // const provider = new RpcProvider({ nodeUrl: 'http://127.0.0.1:5050' });

    const rpcProvider = useProvider()
    const chainId = chain?.chain?.id
    console.log("chainId", chainId)
    // const provider = rpcProvider?.provider ?? new RpcProvider({ nodeUrl:  process.env.STARKNET_RPC_ENDPOINT  });
    // const provider = rpcProvider?.provider ?? new RpcProvider();
    const provider = new RpcProvider();


    const handleBuyKeys = async (account: AccountInterface, user_address: string, tokenQuote: TokenQuoteBuyKeys, amount: number, contractAddress?: string) => {
        if (!account) return;

        let addressContract = contractAddress ?? CONTRACT_ADDRESS.SEPOLIA.KEY
        console.log("addressContract", addressContract)
        console.log("read asset",)
        let asset = await prepareAndConnectContract(
            provider,
            feltToAddress(BigInt(tokenQuote?.token_address)),
            // tokenQuote?.token_address?.toString(),
            account
        );
        console.log("read key_contract",)

        let key_contract = await prepareAndConnectContract(
            provider,
            addressContract,
            account
        );

        console.log("convert float")
        console.log("amount",amount)
        let amountUint256=formatFloatToUint256(amount)
        console.log("amountuint256",amountUint256)
        const buyKeysParams = {
            user_address: user_address, // token address
            amount:amountUint256
            // amount: cairo.uint256(amount), // amount int. Float need to be convert with bnToUint
            // amount: uint256.bnToUint256(amount*10**18), // amount int. Float need to be convert with bnToUint
            // amount: uint256.bnToUint256(BigInt(amount*10**18)), // amount int. Float need to be convert with bnToUint
        };

        console.log("read amountToPaid",)

        let amountToPaid;
        try {
            amountToPaid = await key_contract.get_amount_to_paid(user_address, amount,);

        } catch (error) {
            console.log("Error get amount to paid",error)

        }

        console.log("amount to paid", amountToPaid)
        // let txApprove = await asset.approve(
        //     addressContract,
        //     cairo.uint256(1), // change for decimals float => uint256.bnToUint256("0x"+alicePublicKey)
        // )

        let approveCall = {
            contractAddress: asset?.address,
            entrypoint: 'approve',
            calldata: CallData.compile({
                address: addressContract,
                amount: amountToPaid ?? cairo.uint256(1)
            }),
            // calldata: [buyKeysParams.user_address, buyKeysParams.amount]
        }


        let call = {
            contractAddress: addressContract,
            entrypoint: 'buy_keys',
            calldata: CallData.compile({
                user_address: buyKeysParams.user_address, amount: buyKeysParams.amount,
            }),
            // calldata: [buyKeysParams.user_address, buyKeysParams.amount]
        }


        console.log("Call", call)

        let tx = await account?.execute([approveCall, call], undefined, {})
        console.log("tx hash", tx.transaction_hash)
        let wait_tx = await account?.waitForTransaction(tx?.transaction_hash)


    };


    return { handleBuyKeys }

}