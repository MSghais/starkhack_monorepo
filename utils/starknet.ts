import dotenv from "dotenv";
dotenv.config()

import { Account, Contract, RpcProvider, ec, stark } from "starknet";
const STARKNET_URL = process.env.RPC_ENDPOINT || "http://127.0.0.1:5050";
export const provider = new RpcProvider({nodeUrl:STARKNET_URL});
// export const provider = new RpcProvider();


export const createStarknetWallet = () => {
  try {
    const privateKey = stark.randomAddress();
    console.log("New privateKey=", privateKey);
    const starkKeyPub = ec.starkCurve.getStarkKey(privateKey);
    console.log("publicKey=", starkKeyPub);
    return privateKey;
  } catch (e) {
    return undefined;
  }
};
export function connectToStarknet(nodeUrl?: string) {
  try {
    return new RpcProvider({
      nodeUrl: nodeUrl ?? (process.env.RPC_ENDPOINT as string),
    });
  } catch (e) {}
}

export const connectWallet = (
  accountAddress?: string,
  privateKeyProps?: string
) => {
  try {
    const provider = new RpcProvider({
      nodeUrl: STARKNET_URL as string,
    });
    const privateKey = privateKeyProps ?? (process?.env?.DEV_PK as string);

    const publicKey =
      accountAddress ?? (process.env.DEV_PUBLIC_KEY as string);
    const account = new Account(provider, publicKey, privateKey);

    return account;
  } catch (e) {
    return undefined;
  }
};

/** @TODO determine paymaster master specs to send the TX */
export const prepareAndConnectContract = async (
  addressUser: string,
  account: Account
) => {
  // read abi of Test contract
  const { abi: testAbi } = await provider.getClassAt(addressUser);

  const token = new Contract(testAbi, addressUser, provider);
  // Connect account with the contract
  token.connect(account);
  return token;
};