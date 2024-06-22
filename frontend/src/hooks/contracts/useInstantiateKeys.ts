import KeysMarketplace from "@/components/KeysMarketplace";
import { CONTRACT_ADDRESS } from "@/constants/address";
import { useAccount, useNetwork } from "@starknet-react/core";
import { Account, AccountInterface, Call, CallData, cairo } from "starknet";

export const useInstantiateKeys = () => {

    const account = useAccount();
    const chain = useNetwork()
    const chainId = chain?.chain?.id
    console.log("chainId", chainId)

    const handleInstantiateKeys = async (account: AccountInterface) => {
        if (!account) return;

        let call = {
            contractAddress: CONTRACT_ADDRESS.DEVNET.KEY,
            entrypoint: 'instantiate_keys',
            calldata: CallData.compile({
            }),
        }

        console.log("Call", call)

        let tx = await account?.execute([call], undefined, {})
        console.log("tx hash", tx.transaction_hash)
        let wait_tx = await account?.waitForTransaction(tx?.transaction_hash)


    };


    return { handleInstantiateKeys }

}