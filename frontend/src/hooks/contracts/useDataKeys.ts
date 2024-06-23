import KeysMarketplace from "@/components/KeysMarketplace";
import { CONTRACT_ADDRESS } from "@/constants/address";
import { useAccount, useNetwork, useProvider } from "@starknet-react/core";
import { Account, AccountInterface, Call, CallData, Contract, Provider, ProviderInterface, RpcProvider, cairo } from "starknet";

/** @TODO determine paymaster master specs to send the TX */
export const prepareAndConnectContract = async (
    provider: ProviderInterface,
    contractAddress: string,
    account?: AccountInterface
) => {
    // read abi of Test contract
    console.log("contractAddress",contractAddress)

    const { abi: testAbi } = await provider.getClassAt(contractAddress);
    if (testAbi === undefined) {
        throw new Error('no abi.');
      }
    const contract = new Contract(testAbi, contractAddress, provider);
    console.log("contract",contract)

    // Connect account with the contract
    if(account) {
        contract.connect(account);

    }
    return contract;
};

export const useDataKeys = () => {

    const account = useAccount();
    const chain = useNetwork()
    // const provider = useProvider()
    const chainId = chain?.chain?.id
    console.log("chainId", chainId)
    const provider = new RpcProvider({ nodeUrl:  'http://127.0.0.1:5050'  });


    /** Indexer with Key contract event */
    const getAllKeys = async (account?: AccountInterface) => {
        console.log("get contract")
        console.log("CONTRACT_ADDRESS.DEVNET.KEY",CONTRACT_ADDRESS.DEVNET.KEY)
        const contract = await prepareAndConnectContract(provider, CONTRACT_ADDRESS.DEVNET.KEY, account )

        // if (!account) return;

        console.log("get key all keys")
       
        let all_keys=await contract.get_all_keys()


        console.log("allkeys",all_keys)

        return all_keys
    };


    const getMySharesOfUser = async (account?: AccountInterface) => {
        console.log("get contract")
        console.log("CONTRACT_ADDRESS.DEVNET.KEY",CONTRACT_ADDRESS.DEVNET.KEY)

        const contract = await prepareAndConnectContract(provider, CONTRACT_ADDRESS.DEVNET.KEY, account )

        // if (!account) return;

        console.log("get key all keys")
       
        let all_keys=await contract.get_all_keys()


        console.log("allkeys",all_keys)

        return all_keys
    };



    return { getAllKeys , getMySharesOfUser}

}