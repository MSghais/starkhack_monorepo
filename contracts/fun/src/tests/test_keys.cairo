#[cfg(test)]
mod tests {
    use core::array::SpanTrait;
    use core::traits::Into;
    use joy_fun::erc20::{ERC20, IERC20, IERC20Dispatcher, IERC20DispatcherTrait};

    use joy_fun::keys::{IKeysMarketplaceDispatcher, IKeysMarketplaceDispatcherTrait};
    use joy_fun::types::keys_types::{
        MINTER_ROLE, ADMIN_ROLE, KeysBonding, TokenQuoteBuyKeys, BondingType
    };
    use openzeppelin::account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin::utils::serde::SerializedAppend;
    // use openzeppelin::token::erc20::{ERC20, IERC20, IERC20Dispatcher, IERC20DispatcherTrait};

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
    const STEP_LINEAR_INCREASE: u256 = 1;

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
            escrow_class,
            sender_address,
            token_address.clone(),
            INITIAL_KEY_PRICE,
            STEP_LINEAR_INCREASE
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
        step_increase_linear: u256
    ) -> IKeysMarketplaceDispatcher {
        println!("deploy marketplace");
        let mut calldata = array![admin.into()];
        calldata.append_serde(initial_key_price);
        calldata.append_serde(token_address);
        calldata.append_serde(step_increase_linear);
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
    fn buy_and_sell_one_by_recipient() {
        let (sender_address, erc20, keys) = request_fixture();
        let amount = 100_u256;
        cheat_caller_address_global(sender_address);
        erc20.approve(keys.contract_address, amount);

        let key_address = keys.contract_address;
        let erc20_address = erc20.contract_address;
        // Check default token used
        start_cheat_caller_address(key_address, sender_address);
        let default_token = keys.get_default_token();
        assert(default_token.token_address == erc20.contract_address, 'no default token');
        assert(default_token.initial_key_price == INITIAL_KEY_PRICE, 'no init price');

        // Instantiate keys
        println!("instantiate keys");
        keys.instantiate_keys();

        stop_cheat_caller_address(key_address);
        start_cheat_caller_address(erc20_address, sender_address);

        // Instantite buyer
        let buyer: ContractAddress = 456.try_into().unwrap();
        println!("transfer erc20 to buyer");

        erc20.transfer(buyer, amount);
        // stop_cheat_caller_address(erc20_address);

        // OWner call to buy keys

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, sender_address);
        println!("owner approve erc20 to key");

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        erc20.approve(keys.contract_address, amount_to_paid);
        stop_cheat_caller_address(erc20_address);

        // Second address
        // Buy and sell 

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, buyer);
        println!("buyer approve erc20 to key");
        erc20.approve(keys.contract_address, amount + amount);
        stop_cheat_caller_address(erc20_address);

        // BUy one key

        println!("buy one keys");
        start_cheat_caller_address(keys.contract_address, buyer);
        let mut allowance = erc20.allowance(buyer, keys.contract_address);

        println!("allowance buyer {}", allowance);

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        erc20.approve(keys.contract_address, amount_to_paid);

        println!("amount_to_paid {}", amount_to_paid);



        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);



        // @TODO fix sell key with only 2 total supply
        // Sub overflow
        println!("Sell one keys");

        let mut contract_balance = erc20.balance_of(keys.contract_address);

        let amount_key_sell = 1_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);
        assert!(contract_balance >= amount_to_receive - key_user.initial_key_price, "contract balance to low for sell");
        // assert!(contract_balance >= amount_to_receive, "contract balance to low for sell");

        keys.sell_keys(sender_address, amount_key_sell);

    }


    #[test]
    fn keys_recipient_buy_and_sell_by_owner() {
        let (sender_address, erc20, keys) = request_fixture();
        let amount = 100_u256;
        cheat_caller_address_global(sender_address);
        erc20.approve(keys.contract_address, amount);

        let key_address = keys.contract_address;
        let erc20_address = erc20.contract_address;
        // Check default token used
        start_cheat_caller_address(key_address, sender_address);
        let default_token = keys.get_default_token();
        assert(default_token.token_address == erc20.contract_address, 'no default token');
        assert(default_token.initial_key_price == INITIAL_KEY_PRICE, 'no init price');

        // Instantiate keys
        println!("instantiate keys");
        keys.instantiate_keys();

        stop_cheat_caller_address(key_address);
        start_cheat_caller_address(erc20_address, sender_address);

        // Instantite buyer
        let buyer: ContractAddress = 456.try_into().unwrap();
        println!("transfer erc20 to buyer");

        erc20.transfer(buyer, amount);
        // stop_cheat_caller_address(erc20_address);

        // OWner call to buy keys

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, sender_address);
        println!("owner approve erc20 to key");

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        erc20.approve(keys.contract_address, amount_to_paid);
        stop_cheat_caller_address(erc20_address);

        // Second address
        // Buy and sell 

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, buyer);
        println!("buyer approve erc20 to key");
        erc20.approve(keys.contract_address, amount + amount);
        stop_cheat_caller_address(erc20_address);

        println!("buy one keys");
        start_cheat_caller_address(keys.contract_address, buyer);
        let mut allowance = erc20.allowance(buyer, keys.contract_address);

        println!("allowance buyer {}", allowance);

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        erc20.approve(keys.contract_address, amount_to_paid);

        println!("amount_to_paid {}", amount_to_paid);

        // BUy one key


        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        // BUy second key

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        erc20.approve(keys.contract_address, amount_to_paid);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);


        // @TODO fix sell key with only 2 total supply
        // Sub overflow


        let amount_key_sell = 1_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);


        let mut contract_balance = erc20.balance_of(keys.contract_address);

        let amount_key_sell = 1_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);
        assert!(contract_balance >= amount_to_receive - key_user.initial_key_price, "contract balance to low for sell");
        

        keys.sell_keys(sender_address, amount_key_sell);


    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 10 keys");
    // let amount_key_buy = 10_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 100 keys");
    // let amount_key_buy = 100_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 1000 keys");
    // let amount_key_buy = 1000_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    }


    #[test]
    fn keys_end_to_end() {
        let (sender_address, erc20, keys) = request_fixture();
        let amount = 100_u256;
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
        start_cheat_caller_address(erc20_address, sender_address);

        // Instantite buyer
        let buyer: ContractAddress = 456.try_into().unwrap();
        println!("transfer erc20 to buyer");

        erc20.transfer(buyer, amount);
        // stop_cheat_caller_address(erc20_address);

        // OWner call to buy keys

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, sender_address);
        println!("owner approve erc20 to key");

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        erc20.approve(keys.contract_address, amount_to_paid);
        stop_cheat_caller_address(erc20_address);

        println!("owner buy one keys");
        start_cheat_caller_address(keys.contract_address, sender_address);
        let mut allowance = erc20.allowance(sender_address, keys.contract_address);

        println!("allowance owner {}", allowance);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        assert!(key_user.total_supply == 1 + amount_key_buy, "key user not updated");

        // Second address
        // Buy and sell 

        let amount_key_buy = 5_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, buyer);
        println!("buyer approve erc20 to key");

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        erc20.approve(keys.contract_address, amount_to_paid);
        stop_cheat_caller_address(erc20_address);

        println!("buy one keys");
        start_cheat_caller_address(keys.contract_address, buyer);
        let mut allowance = erc20.allowance(buyer, keys.contract_address);

        println!("allowance buyer {}", allowance);


        println!("amount_to_paid {}", amount_to_paid);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        let amount_key_sell = 2_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);

        // Contract check before sell
        let mut contract_balance = erc20.balance_of(keys.contract_address);

        // let amount_key_sell = 1_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);
        assert!(contract_balance >= amount_to_receive - key_user.initial_key_price, "contract balance to low for sell");
        


        keys.sell_keys(sender_address, amount_key_sell);
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 10 keys");
    // let amount_key_buy = 10_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 100 keys");
    // let amount_key_buy = 100_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 1000 keys");
    // let amount_key_buy = 1000_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    }


    #[test]
    fn keys_test_exemple() {
        let (sender_address, erc20, keys) = request_fixture();
        let amount = 100_u256;
        cheat_caller_address_global(sender_address);
        // erc20.approve(keys.contract_address, amount);
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
        start_cheat_caller_address(erc20_address, sender_address);

        // Instantite buyer
        let buyer: ContractAddress = 456.try_into().unwrap();
        println!("transfer erc20 to buyer");

        erc20.transfer(buyer, amount);
        // stop_cheat_caller_address(erc20_address);

        // OWner call to buy keys

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, sender_address);
        println!("owner approve erc20 to key");

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        erc20.approve(keys.contract_address, amount_to_paid);
        stop_cheat_caller_address(erc20_address);

        println!("owner buy one keys");
        start_cheat_caller_address(keys.contract_address, sender_address);
        let mut allowance = erc20.allowance(sender_address, keys.contract_address);

        println!("allowance owner {}", allowance);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        assert!(key_user.total_supply == 1 + amount_key_buy, "key user not updated");

        // Second address
        // Buy and sell 

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, buyer);
        println!("buyer approve erc20 to key");
        erc20.approve(keys.contract_address, amount + amount);
        stop_cheat_caller_address(erc20_address);

        println!("buy one keys");
        start_cheat_caller_address(keys.contract_address, buyer);
        let mut allowance = erc20.allowance(buyer, keys.contract_address);

        println!("allowance buyer {}", allowance);

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        let amount_key_sell = 1_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);
        keys.sell_keys(sender_address, amount_key_sell);
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 10 keys");
    // let amount_key_buy = 10_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 100 keys");
    // let amount_key_buy = 100_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    // println!("buy 1000 keys");
    // let amount_key_buy = 1000_u256;
    // keys.buy_keys(sender_address, amount_key_buy);

    }

    #[test]
    fn keys_everything() {
        let (sender_address, erc20, keys) = request_fixture();
        let amount = 100_u256;
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
        start_cheat_caller_address(erc20_address, sender_address);

        // Instantite buyer
        let buyer: ContractAddress = 456.try_into().unwrap();
        println!("transfer erc20 to buyer");

        erc20.transfer(buyer, amount);
        // stop_cheat_caller_address(erc20_address);

        // OWner call to buy keys

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, sender_address);
        println!("owner approve erc20 to key");

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        erc20.approve(keys.contract_address, amount_to_paid);
        stop_cheat_caller_address(erc20_address);

        println!("owner buy one keys");
        start_cheat_caller_address(keys.contract_address, sender_address);
        let mut allowance = erc20.allowance(sender_address, keys.contract_address);

        println!("allowance owner {}", allowance);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        assert!(key_user.total_supply == 1 + amount_key_buy, "key user not updated");

        // Second address
        // Buy and sell 

        let amount_key_buy = 1_u256;

        cheat_caller_address_global(buyer);
        start_cheat_caller_address(erc20_address, buyer);
        println!("buyer approve erc20 to key");
        erc20.approve(keys.contract_address, amount + amount);
        stop_cheat_caller_address(erc20_address);

        println!("buy one keys");
        start_cheat_caller_address(keys.contract_address, buyer);
        let mut allowance = erc20.allowance(buyer, keys.contract_address);

        println!("allowance buyer {}", allowance);

        let amount_to_paid = keys
            .get_price_of_supply_key(
                sender_address, amount_key_buy, false, // BondingType::Basic, default_token
            );
        println!("amount_to_paid {}", amount_to_paid);

        keys.buy_keys(sender_address, amount_key_buy);

        let key_user = keys.get_key_of_user(sender_address);
        println!("key_user owner total_supply {:?}", key_user.total_supply);

        let amount_key_sell = 1_u256;
        let amount_to_receive = keys
            .get_price_of_supply_key(
                sender_address, amount_key_sell, true, // BondingType::Basic, default_token
            );
        println!("amount_to_receive {}", amount_to_receive);
        keys.sell_keys(sender_address, amount_key_sell);
        // keys.buy_keys(sender_address, amount_key_buy);

        println!("buy 10 keys");
        let amount_key_buy = 10_u256;
        keys.buy_keys(sender_address, amount_key_buy);
    }
}
