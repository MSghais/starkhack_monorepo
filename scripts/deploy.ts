import {
    provider,
} from "../utils/starknet";

import { Account, byteArray, cairo, uint256 } from "starknet";
import { CONTRACT_ADDRESS, TOKENS_ADDRESS} from "./constants";
import dotenv from "dotenv";
import {  createKeysMarketplace } from "../utils/keys";
import { createToken, prepareAndConnectContract, transferToken } from "../utils/token";
dotenv.config();

export const deployKeys = async () => {
    console.log("deploy keys")

    let keys_address: string | undefined = CONTRACT_ADDRESS.DEVNET.KEY // change default address

    const privateKey0 = process.env.DEV_PK as string;
    const accountAddress0 = process.env.DEV_PUBLIC_KEY as string;
    const account = new Account(provider, accountAddress0, privateKey0, "1");
    let key_marketplace;

    // let token = await createToken()
    let token = await transferToken(account, "0x0545d0b3af7412C4e93de7B34461D63601e6dFd1fFc63621A6B8C4b677e36b77", TOKENS_ADDRESS.DEVNET.ETH)
    if (process.env.IS_DEPLOY_CONTRACT == "true") {
      console.log('try deploy key marketplace')

        let keysContract = await createKeysMarketplace(
            TOKENS_ADDRESS.SEPOLIA.BIG_TOKEN,
            // 0.01
            1,
            0.01
            

        );
        console.log("keys contract address", keysContract?.contract_address)

        if (keysContract?.contract_address) {
            keys_address = keysContract?.contract_address
        }
        key_marketplace = await prepareAndConnectContract(
            keysContract?.contract_address ?? keys_address, // uncomment if you recreate a contract
            account
        );
    } else {
        key_marketplace = await prepareAndConnectContract(
            keys_address ?? keys_address,
            account
        );
    }

    return {
        key_marketplace, keys_address
    }
}

deployKeys()