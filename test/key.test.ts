import {
  prepareAndConnectContract,
  provider,
} from "../utils/starknet";
import { Account, Contract, byteArray, cairo, uint256 } from "starknet";
import { CONTRACT_ADDRESS, TOKENS_ADDRESS } from "../scripts/constants";
import dotenv from "dotenv";
import { buyKeys, createKeysMarketplace, instantiateKeys, sellKeys } from "../utils/keys";
import { createToken } from "../utils/token";
dotenv.config();

let key_address: string = CONTRACT_ADDRESS.DEVNET.KEY // change default address
let token_used_address = TOKENS_ADDRESS.DEVNET.ETH;
// let token_used_address = TOKENS_ADDRESS.DEVNET.BIG_TOKEN;
let keyContract: Contract;
let tokenContract: Contract;

describe("Keys marketplace End to end test", () => {
  it("Deploy Keys marketplace", async function () {
    this.timeout(0); // Disable timeout for this test
    const privateKey0 = process.env.DEV_PK as string;
    const accountAddress0 = process.env.DEV_PUBLIC_KEY as string;
    const account = new Account(provider, accountAddress0, privateKey0, "1");



    // if (process.env.IS_DEVNET == "true"
    //   || process.env.RPC_ENDPOINT?.includes("http://localhost")

    // ) {
    //   let token = await createToken();
    //   tokenContract = tokenContract

    // }
    if (process.env.IS_DEPLOY_CONTRACT == "true") {


      let keysContract = await createKeysMarketplace(
        // tokenContract?.address,
        token_used_address,

        // TOKENS_ADDRESS.SEPOLIA.BIG_TOKEN,
        // 0.01
        1
      );

      console.log("keysContract address", keysContract?.contract_address)

      if (keysContract?.contract_address) {
        key_address = keysContract?.contract_address
      }
      keyContract = await prepareAndConnectContract(
        keysContract?.contract_address ?? key_address, // uncomment if you recreate a contract
        account
      );
    } else {
      keyContract = await prepareAndConnectContract(
        key_address,
        account
      );
    }
  });

  it("Buy keys", async function () {
    this.timeout(0); // Disable timeout for this test
    const privateKey0 = process.env.DEV_PK as string;
    const accountAddress0 = process.env.DEV_PUBLIC_KEY as string;
    const account = new Account(provider, accountAddress0, privateKey0, "1");

    // let key_contract = keyContract
    //   ?? await prepareAndConnectContract(
    //     key_address,
    //     account
    //   );
    let key_contract = await prepareAndConnectContract(
      key_address,
      account
    );

    /** Send a note */
    let amount: number = 1;
    let strkToken = await prepareAndConnectContract(
      token_used_address,
      account
    );


    // await account?.waitForTransaction(txApprove?.transaction_hash)
    // Need an approve before




    let amountToPaid= await key_contract.get_amount_to_paid(account?.address, amount,);

    console.log("amountToPaid",amountToPaid);
    console.log("try approve key erc20");

    let txApprove = await strkToken.approve(
      key_contract?.address,
      cairo.uint256(amountToPaid), // change for decimals float => uint256.bnToUint256("0x"+alicePublicKey)
    )
    console.log("instantiate keys");


    // await instantiateKeys(
    //   account,
    //   key_contract
    //   // key_contract,

    //   // strkToken?.address,
    // )
    console.log("buy keys");

    await buyKeys(
      {
        key_contract,
        user_address: account?.address,
        account,
        amount,
        tokenAddress: strkToken.address
      }
      // key_contract,
      // strkToken?.address,
    )
    console.log("buy keys");

    await sellKeys(
      {
        key_contract,
        user_address: account?.address,
        account,
        amount,
        tokenAddress: strkToken.address
      }
      // key_contract,
      // strkToken?.address,
    )
    // expect(cairo.uint256(depositCurrentId?.amount)).to.deep.eq(depositParams?.amount)

  });


  // it("Init keys", async function () {
  //   this.timeout(0); // Disable timeout for this test
  //   const privateKey0 = process.env.DEV_PK as string;
  //   const accountAddress0 = process.env.DEV_PUBLIC_KEY as string;
  //   const account = new Account(provider, accountAddress0, privateKey0, "1");

  //   // let key_contract = await prepareAndConnectContract(
  //   //   key_address,
  //   //   account
  //   // );

  //   /** Send a note */
  //   let amount: number = 1;
  //   let strkToken = await prepareAndConnectContract(
  //     token_used_address,
  //     account
  //   );

  //   // console.log("try approve escrow erc20")
  //   // let txApprove = await strkToken.approve(
  //   //   key_contract?.address,
  //   //   cairo.uint256(amount), // change for decimals float => uint256.bnToUint256("0x"+alicePublicKey)
  //   // )

  //   // await account?.waitForTransaction(txApprove?.transaction_hash)
  //   // Need an approve before
  //   console.log("instantiateKeys")

  //   await instantiateKeys(
  //     account,
  //     keyContract
  //     // key_contract,

  //     // strkToken?.address,
  //   )

  //   // expect(cairo.uint256(depositCurrentId?.amount)).to.deep.eq(depositParams?.amount)

  // });



});
