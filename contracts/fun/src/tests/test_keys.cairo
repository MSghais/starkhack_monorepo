#[cfg(test)]
mod tests {
    use core::array::SpanTrait;
    use core::traits::Into;
    use joy_fun::erc20::{ERC20, IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use joy_fun::keys::{IKeysMarketplaceDispatcher, IKeysMarketplaceDispatcherTrait};
    use joy_fun::keys_types::{KeysBonding, TokenQuoteBuyKeys, BondingType, MINTER_ROLE, ADMIN_ROLE};
    use openzeppelin::account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin::utils::serde::SerializedAppend;

    use snforge_std::{
        declare, ContractClass, ContractClassTrait, spy_events, SpyOn, EventSpy, EventFetcher,
        Event, EventAssertions, start_cheat_caller_address, cheat_caller_address_global,
        stop_cheat_caller_address, stop_cheat_caller_address_global, start_cheat_block_timestamp
    };
    // const INITIAL_KEY_PRICE:u256=1/100;

    use starknet::{
        ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        get_block_timestamp, get_contract_address
    };

    // const INITIAL_KEY_PRICE:u256=1/100;
    const INITIAL_KEY_PRICE: u256 = 1;

    fn request_fixture() -> (ContractAddress, IERC20Dispatcher, IKeysMarketplaceDispatcher) {
        println!("request_fixture");
        let erc20_class = declare_erc20();
        let keys_class = declare_marketplace();
        request_fixture_custom_classes(erc20_class, keys_class)
    }

    fn request_fixture_custom_classes(
        erc20_class: ContractClass, escrow_class: ContractClass
    ) -> (ContractAddress, IERC20Dispatcher, IKeysMarketplaceDispatcher) {
        let sender_address: ContractAddress = 123.try_into().unwrap();
        let erc20 = deploy_erc20(erc20_class, 'USDC token', 'USDC', 1_000_000, sender_address);
        let token_address = erc20.contract_address.clone();
        let keys = deploy_marketplace(
            escrow_class, sender_address, token_address.clone(), INITIAL_KEY_PRICE
        );
        (sender_address, erc20, keys)
    }

    fn declare_marketplace() -> ContractClass {
        declare("KeysMarketplace").unwrap()
    }

    fn declare_erc20() -> ContractClass {
        declare("ERC20").unwrap()
    }

    fn deploy_marketplace(
        class: ContractClass,
        admin: ContractAddress,
        token_address: ContractAddress,
        initial_key_price: u256,
    ) -> IKeysMarketplaceDispatcher {
        println!("deploy marketplace");
        let mut calldata = array![admin.into()];
        calldata.append_serde(initial_key_price);
        calldata.append_serde(token_address);
        let (contract_address, _) = class.deploy(@calldata).unwrap();
        IKeysMarketplaceDispatcher { contract_address }
    }

    fn deploy_erc20(
        class: ContractClass,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress
    ) -> IERC20Dispatcher {
        let mut calldata = array![];

        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        (2 * initial_supply).serialize(ref calldata);
        recipient.serialize(ref calldata);
        18_u8.serialize(ref calldata);

        let (contract_address, _) = class.deploy(@calldata).unwrap();

        IERC20Dispatcher { contract_address }
    }

    #[test]
    fn keys_end_to_end() {
            let (sender_address, erc20, keys) = request_fixture();
        let amount_approve = 10000_u256;
        let amount = 10_u256;
        cheat_caller_address_global(sender_address);
        erc20.approve(keys.contract_address, amount);
        // stop_cheat_caller_address_global();

        let key_address = keys.contract_address;
        let erc20_address = erc20.contract_address;
        // Call a view function of the contract

        // Check default token used
        start_cheat_caller_address(key_address, sender_address);
        let default_token = keys.get_default_token();
        assert(default_token.token_address == erc20.contract_address, 'no default token');
        assert(default_token.initial_key_price == INITIAL_KEY_PRICE, 'no init price');

        // Instantiate keys
        println!("instantiate keys");

        keys.instantiate_keys();

        stop_cheat_caller_address(key_address);
        // Instantite buyer
        let buyer: ContractAddress = 456.try_into().unwrap();
        println!("transfer erc20 to buyer");
        start_cheat_caller_address(erc20_address, sender_address);

        erc20.transfer(buyer, amount);
        stop_cheat_caller_address(erc20_address);
        stop_cheat_caller_address_global();

        // Buyer call to buy keys

        let amount_key_buy = 1_u256;
        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, buyer);
        println!("buyer approve erc20 to key");

        erc20.approve(keys.contract_address, amount_approve + amount_approve);

        let amount_to_paid = keys
            .get_amount_to_paid(sender_address, amount_key_buy, //    1,
            // BondingType::Basic, default_token.clone()
            );
        println!("amount_to_paid {}", amount_to_paid);
        erc20.approve(key_address, amount_to_paid + amount_to_paid);
        // erc20.approve(key_address, 10000 + 10000);
        erc20.approve(key_address, amount_approve + amount_approve);

       let allowance = erc20.allowance(buyer, keys.contract_address);
        // erc20.approve(key_address, amount + amount);
        println!("allowance {}", allowance);

        println!("transfer from");
        // erc20.transfer_from(key_address, key_address, amount );

        start_cheat_caller_address(keys.contract_address, buyer);

        println!("buy one keys");

        keys.buy_keys(sender_address, amount_key_buy);

        println!("sell 1 keys");

        let amount_key_sell = 1_u256;
        let amount_to_paid = keys.get_amount_to_paid(sender_address, amount_key_buy,// BondingType::Basic, default_token
        );
        println!("amount_to_paid {}", amount_to_paid);
        keys.sell_keys(sender_address, amount_key_sell);
        // let ( sender_address, erc20, keys) = request_fixture();
        // let amount = 100_u256;
        // cheat_caller_address_global(sender_address);
        // erc20.approve(keys.contract_address, amount);
        // stop_cheat_caller_address_global();


    //     let key_address=keys.contract_address;
    //     let erc20_address=erc20.contract_address;
    //     // Call a view function of the contract

    //     // Check default token used
    //     start_cheat_caller_address(key_address, sender_address);
    //     let default_token= keys.get_default_token();
    //     assert(default_token.token_address == erc20.contract_address, 'no default token');
    //     assert(default_token.initial_key_price == INITIAL_KEY_PRICE, 'no default token');

    //     // Instantiate keys
    //     println!("instantiate keys");

    //     keys.instantiate_keys();

    //     stop_cheat_caller_address(key_address);
    //     // Instantite buyer
    //     let buyer: ContractAddress = 456.try_into().unwrap();
    //     println!("transfer erc20 to buyer");
    //     start_cheat_caller_address(erc20_address, sender_address);

    //     erc20.transfer(buyer, amount);
    //     stop_cheat_caller_address(erc20_address);

    //     // Buyer call to buy keys

    //     let amount_key_buy = 1_u256;

    //     cheat_caller_address_global(buyer);
    //     start_cheat_caller_address(erc20_address, buyer);

    //     start_cheat_caller_address(keys.contract_address, buyer);
    //     println!("buyer approve erc20 to key");

    //     erc20.approve(keys.contract_address, amount);
    //     println!("buy one keys");

    //     start_cheat_caller_address(keys.contract_address, buyer);
    //     keys.buy_keys(sender_address, amount_key_buy);

    //     println!("buy 10 keys");
    //     let amount_key_buy = 10_u256;
    //     keys.buy_keys(sender_address, amount_key_buy);
        // let ( sender_address, erc20, keys) = request_fixture();
        // let amount = 100_u256;
        // cheat_caller_address_global(sender_address);
        // erc20.approve(keys.contract_address, amount);
        // // stop_cheat_caller_address_global();


        // let key_address=keys.contract_address;
        // let erc20_address=erc20.contract_address;
        // // Call a view function of the contract

        // // Check default token used
        // start_cheat_caller_address(key_address, sender_address);
        // let default_token= keys.get_default_token();
        // assert(default_token.token_address == erc20.contract_address, 'no default token');
        // assert(default_token.initial_key_price == INITIAL_KEY_PRICE, 'no init price');

        // // Instantiate keys
        // println!("instantiate keys");

        // keys.instantiate_keys();

        // stop_cheat_caller_address(key_address);
        // // Instantite buyer
        // let buyer: ContractAddress = 456.try_into().unwrap();
        // println!("transfer erc20 to buyer");
        // start_cheat_caller_address(erc20_address, sender_address);

        // erc20.transfer(buyer, amount);
        // // stop_cheat_caller_address(erc20_address);

        // // Buyer call to buy keys
        
        // let amount_key_buy = 1_u256;

        // cheat_caller_address_global(buyer);
        // start_cheat_caller_address(erc20_address, buyer);
        // println!("buyer approve erc20 to key");

        // erc20.approve(keys.contract_address, amount+ amount);
        // erc20.approve(key_address,  amount+ amount);
        // erc20.approve(key_address,  amount+ amount);

        // start_cheat_caller_address(keys.contract_address, buyer);

        // println!("buy one keys");

        // start_cheat_caller_address(keys.contract_address, buyer);
        // keys.buy_keys(sender_address, amount_key_buy);

        // println!("buy 10 keys");
        // let amount_key_buy = 10_u256;
        // keys.buy_keys(sender_address, amount_key_buy);


        // println!("buy 100 keys");
        // let amount_key_buy = 100_u256;
        // keys.buy_keys(sender_address, amount_key_buy);



        // println!("buy 1000 keys");
        // let amount_k
        }

    // #[test]
    // fn keys_end_to_end() {
    //     let (sender_address, erc20, keys) = request_fixture();
    //     let amount_approve = 10000_u256;
    //     let amount = 100_u256;
    //     cheat_caller_address_global(sender_address);
    //     erc20.approve(keys.contract_address, amount);
    //     // stop_cheat_caller_address_global();

    //     let key_address = keys.contract_address;
    //     let erc20_address = erc20.contract_address;
    //     // Call a view function of the contract

    //     // Check default token used
    //     start_cheat_caller_address(key_address, sender_address);
    //     let default_token = keys.get_default_token();
    //     assert(default_token.token_address == erc20.contract_address, 'no default token');
    //     assert(default_token.initial_key_price == INITIAL_KEY_PRICE, 'no init price');

    //     // Instantiate keys
    //     println!("instantiate keys");
    //     keys.instantiate_keys();
    //     stop_cheat_caller_address_global();

    //     stop_cheat_caller_address(key_address);
    //     // Instantite buyer
    //     let buyer: ContractAddress = 456.try_into().unwrap();
    //     println!("transfer erc20 to buyer");
    //     start_cheat_caller_address(erc20_address, buyer);

    //     stop_cheat_caller_address_global();

    //     // erc20.transfer(buyer, amount);
    //     // erc20.transfer(buyer, amount);
    //     // stop_cheat_caller_address(erc20_address);
    //     cheat_caller_address_global(buyer);

    //     // Buyer call to buy keys
    //     start_cheat_caller_address(erc20.contract_address, buyer);

    //     let amount_key_buy = 1_u256;
    //     let amount_key_buy_approve = 100_u256;
    //     // start_cheat_caller_address(erc20_address, buyer);
    //     start_cheat_caller_address(erc20.contract_address, buyer);
    //     println!("buyer approve erc20 to key");
    //     erc20.approve(keys.contract_address, amount+ amount);
    //     erc20.approve(keys.contract_address, amount_approve + amount_approve);

    //     let amount_to_paid = keys
    //         .get_amount_to_paid(sender_address, amount_key_buy, //    1,
    //         // BondingType::Basic, default_token.clone()
    //         );
    //     println!("amount_to_paid {}", amount_to_paid);
    //     erc20.approve(key_address, amount_to_paid + amount_to_paid);

    //     println!("amount_to_paid {}", amount_to_paid);
    //     erc20.approve(key_address, amount_to_paid + amount_to_paid);
    //     erc20.approve(keys.contract_address, amount_to_paid + amount_to_paid);
    //     println!("transfer from");
    //     // erc20.transfer_from(key_address, key_address, amount );
    //     start_cheat_caller_address(keys.contract_address, buyer);
    //     println!("buy one keys");

    //     start_cheat_caller_address(keys.contract_address, buyer);
    //     erc20.approve(key_address, amount + amount);
    //     start_cheat_caller_address(keys.contract_address, buyer);
    //     keys.buy_keys(sender_address, amount_key_buy);

    //     // println!("buy 10 keys");
    //     // let amount_key_buy = 10_u256;
    //     // let amount_to_paid = keys.get_amount_to_paid(sender_address, amount_key_buy,// BondingType::Basic, default_token
    //     // );
    //     // erc20.approve(key_address, amount_to_paid + amount_to_paid);

    //     // println!("amount_to_paid {}", amount_to_paid);
    //     // keys.buy_keys(sender_address, amount_key_buy);

  

    // // println!("buy 100 keys");
    // // let amount_key_buy = 100_u256;
    // // keys.buy_keys(sender_address, amount_key_buy);

    // // println!("buy 1000 keys");
    // // let amount_key_buy = 1000_u256;
    // // keys.buy_keys(sender_address, amount_key_buy);

    // }
}
