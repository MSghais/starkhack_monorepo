use core::num::traits::Zero;
use starknet::ContractAddress;
use joy_fun::keys_types::{
        StoredName, BuyKeys, SellKeys, CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys,
        BondingType, KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE
};


#[starknet::interface]
pub trait IKeysMarketplace<TContractState> {
    fn set_token(ref self: TContractState, token_quote: TokenQuoteBuyKeys);
    fn set_protocol_fee_percent(ref self: TContractState, protocol_fee_percent: u256);
    fn set_creator_fee(ref self: TContractState, creator_fee: u256);
    fn store_name(
        ref self: TContractState,
        name: felt252, // registration_type: KeysMarketplace::BondingType
        registration_type: BondingType
    );
    fn instantiate_keys(
        ref self: TContractState,
        token_quote: TokenQuoteBuyKeys, // registration_type: KeysMarketplace::BondingType,
    );
    fn buy_keys(ref self: TContractState, address_user: ContractAddress, amount: u256);
    fn sell_keys(ref self: TContractState, amount: u256);
// fn get_name(self: @TContractState, address: ContractAddress) -> felt252;
// fn get_owner(self: @TContractState) -> KeysMarketplace::Person;
}

#[starknet::contract]
mod KeysMarketplace {
    use core::num::traits::Zero;
    use super::{
        StoredName, BuyKeys, SellKeys, CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys,
        BondingType, KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE
    };

    use openzeppelin::access::accesscontrol::{AccessControlComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    // use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    // use joy_fun::erc20::{ERC20, ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use joy_fun::erc20::{ERC20,  IERC20Dispatcher, IERC20DispatcherTrait};

    // use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{
        ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        contract_address_const, get_block_timestamp, get_contract_address,
    };

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
   component!(path: SRC5Component, storage: src5, event: SRC5Event);
    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        names: LegacyMap::<ContractAddress, felt252>,
        keys_of_users: LegacyMap::<ContractAddress, Keys>,
        shares_by_users: LegacyMap::<(ContractAddress, ContractAddress), SharesKeys>,
        registration_type: LegacyMap::<ContractAddress, BondingType>,
        total_names: u128,
        initial_key_price: u256,
        protocol_fee_percent: u256,
        creator_fee: u256,
        is_fees_protocol: bool,
        is_tokens_buy_enable: LegacyMap::<ContractAddress, TokenQuoteBuyKeys>,
        default_token: TokenQuoteBuyKeys,
        is_custom_key_enable: bool,
        is_custom_token_enable: bool,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StoredName: StoredName,
        BuyKeys: BuyKeys,
        SellKeys: SellKeys,
        CreateKeys: CreateKeys,
        KeysUpdated: KeysUpdated,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        // init_token: TokenQuoteBuyKeys,
        initial_key_price: u256,
        token_address:ContractAddress,
    ) {
        // AccessControl-related initialization
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(MINTER_ROLE, admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin);

        let init_token= TokenQuoteBuyKeys{
            token_address: token_address,
            initial_key_price,
            price: initial_key_price,
            is_enable: true
        };
        self.default_token.write(init_token.clone());

        self.initial_key_price.write(init_token.initial_key_price);

        // self.initial_key_price.write(initial_key_price);
    }


    // #[constructor]
    // fn constructor(
    //     ref self: ContractState,
    //     admin: ContractAddress,
    //     init_token: TokenQuoteBuyKeys,
    //     // initial_key_price: u256,
    // ) {
    //     // AccessControl-related initialization
    //     self.accesscontrol.initializer();
    //     self.accesscontrol._grant_role(MINTER_ROLE, admin);
    //     self.accesscontrol._grant_role(ADMIN_ROLE, admin);

    //     self.default_token.write(init_token.clone());
    //     self.initial_key_price.write(init_token.initial_key_price);

    //     // self.initial_key_price.write(initial_key_price);
    // }

    // Public functions inside an impl block
    #[abi(embed_v0)]
    impl KeysMarketplace of super::IKeysMarketplace<ContractState> {
        // ADMIN

        fn set_token(ref self: ContractState, token_quote: TokenQuoteBuyKeys) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.is_tokens_buy_enable.write(token_quote.token_address, token_quote);
        }

        fn set_protocol_fee_percent(ref self: ContractState, protocol_fee_percent: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.protocol_fee_percent.write(protocol_fee_percent);
        }

        fn set_creator_fee(ref self: ContractState, creator_fee: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.creator_fee.write(creator_fee);
        }

        fn store_name(ref self: ContractState, name: felt252, registration_type: BondingType) {
            let caller = get_caller_address();
            self._store_name(caller, name, registration_type);
        }

        // User

        // Create keys for an user
        fn instantiate_keys(
            ref self: ContractState,
            token_quote: TokenQuoteBuyKeys, // registration_type: BondingType, 
        ) {
            let caller = get_caller_address();
            let keys = self.keys_of_users.read(caller);
            assert!(keys.owner.is_zero(), "key already created");
            let initial_key_price = self.initial_key_price.read();

            let mut token_to_use = self.default_token.read();
            if self.is_custom_token_enable.read() {
                token_to_use = token_quote;
            }
            let key = Keys {
                owner: caller,
                token_address: caller, // CREATE 404
                price: initial_key_price,
                total_supply: 1,
                bonding_curve_type: BondingType::Basic,
                created_at: get_block_timestamp(),
                token_quote: token_to_use
            };

            let share_user = SharesKeys {
                owner: get_caller_address(),
                key_address: get_caller_address(),
                amount_owned: 1,
                amount_buy: 1,
                amount_sell: 0,
                created_at: get_block_timestamp(),
            };
            self.shares_by_users.write((get_caller_address(), get_caller_address()), share_user);
            self._update_keys(caller, key);
        }

        fn buy_keys(ref self: ContractState, address_user: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let old_keys = self.keys_of_users.read(address_user);
            assert!(!old_keys.owner.is_zero(), "key not found");
            let initial_key_price = self.initial_key_price.read();

            // TODO erc20 token transfer
            let token = old_keys.token_quote.clone();
            let token_address = old_keys.token_address;
            let bonding_curve_type = old_keys.bonding_curve_type;
            let total_supply = old_keys.total_supply;

            let erc20 = IERC20Dispatcher { contract_address: token_address };
            let amount_transfer = token.initial_key_price;
            let protocol_fee_percent = self.protocol_fee_percent.read();
            // let amount_creator_fee=price*protocol_fee_percent;

            // Update keys with new values
            let mut key = Keys {
                owner: caller,
                token_address: token_address, // CREATE 404
                created_at: old_keys.created_at,
                token_quote: token,
                price: initial_key_price,
                total_supply: total_supply + amount,
                bonding_curve_type: bonding_curve_type,
            };
            let price = KeysBonding::calculate_new_price(key.clone(), amount);
            let amount_protocol_fee = price * protocol_fee_percent;
            let creator_amount = price / amount_protocol_fee;

            key.price = price;

            let mut old_share = self
                .shares_by_users
                .read((get_caller_address(), get_caller_address()));

            let share_user = old_share;
            // if old_share.sender == ContractAddress::zero() {
            //     let share_user=SharesKeys {
            //         owner:get_caller_address(),
            //         key_address:get_caller_address(),
            //         amount_owned:amount,
            //         amount_buy:amount,
            //         amount_sell:0,
            //         created_at:get_block_timestamp(),
            //     };
            // } else {
            // }

            self.shares_by_users.write((get_caller_address(), address_user), share_user);
            erc20.transfer(get_contract_address(), amount_protocol_fee);
            erc20.transfer(get_caller_address(), creator_amount);

            self._update_keys(address_user, key);
        }

        fn sell_keys(ref self: ContractState, amount: u256) { // let caller = get_caller_address();
        // self._update_keys(caller, name, registration_type);

        }
    // fn get_name(self: @ContractState, address: ContractAddress) -> felt252 {
    //     self.names.read(address)
    // }

    // fn get_owner(self: @ContractState) -> Person {
    //     self.owner.read()
    // }
    }


    // Could be a group of functions about a same topic
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _store_name(
            ref self: ContractState,
            user: ContractAddress,
            name: felt252,
            registration_type: BondingType
        ) { // let total_names = self.total_names.read();
        // self.names.write(user, name);
        // self.registration_type.write(user, registration_type);
        // self.total_names.write(total_names + 1);
        // self.emit(StoredName { user: user, name: name });
        }

        fn _update_keys(
            ref self: ContractState, user: ContractAddress, keys: Keys, // name: felt252,
        // registration_type: BondingType
        ) { // let total_names = self.total_names.read();
        // self.names.write(user, name);
        // self.registration_type.write(user, registration_type);
        // self.total_names.write(total_names + 1);
        // self.emit(StoredName { user: user, name: name });
        }

    }

}


#[cfg(test)]
mod tests {
    use super::{IKeysMarketplaceDispatcher, IKeysMarketplaceDispatcherTrait, KeysBonding,TokenQuoteBuyKeys, BondingType, MINTER_ROLE, ADMIN_ROLE};

    use core::array::SpanTrait;
    use core::traits::Into;
    use openzeppelin::account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    // use joy_fun::erc20::{ERC20, ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    // use joyboy::erc20::{ERC20,  IERC20Dispatcher, IERC20DispatcherTrait};
    // use joy_fun::erc20::{ERC20,  IERC20Dispatcher, IERC20DispatcherTrait};
    
    use joy_fun::erc20::{ERC20, IERC20,  IERC20Dispatcher, IERC20DispatcherTrait};

    use openzeppelin::utils::serde::SerializedAppend;

    use snforge_std::{
        declare, ContractClass, ContractClassTrait, spy_events, SpyOn, EventSpy, EventFetcher,
        Event, EventAssertions, 
        start_cheat_caller_address, cheat_caller_address_global,
        stop_cheat_caller_address_global, start_cheat_block_timestamp
    };

    use starknet::{
        ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        get_block_timestamp, get_contract_address
    };

    fn request_fixture() -> (
        ContractAddress, IERC20Dispatcher, 
        IKeysMarketplaceDispatcher
    ) {
        println!("request_fixture");
        let erc20_class = declare_erc20();
        let keys_class = declare_marketplace();
        // request_fixture_custom_classes(erc20_class)
        request_fixture_custom_classes(erc20_class, keys_class)
    }

    fn request_fixture_custom_classes(
        erc20_class: ContractClass, escrow_class: ContractClass
    ) -> (ContractAddress, IERC20Dispatcher, 
        IKeysMarketplaceDispatcher
    ) {

        let sender_address: ContractAddress = 123.try_into().unwrap();
        let initial_key_price:u256=1;
        let erc20 = deploy_erc20(erc20_class, 'USDC token', 'USDC', 100, sender_address);
        let token_address=erc20.contract_address.clone();
        // let init_token = TokenQuoteBuyKeys {
        //     token_address: erc20.contract_address.clone(),
        //     initial_key_price,
        //     price: initial_key_price,
        //     is_enable: true
        // };
        // assert(init_token.token_address, erc20.contract_address);
        // assert(init_token.is_enable, true);
        // (sender_address, erc20)

        // let keys = deploy_marketplace(escrow_class, sender_address, init_token.clone(), initial_key_price);
        let keys = deploy_marketplace(escrow_class, sender_address, token_address.clone(), initial_key_price);
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
        token_address:ContractAddress,
        initial_key_price: u256,
    ) -> IKeysMarketplaceDispatcher {
        let mut calldata = array![admin.into()];

        println!("deploy marketplace");
        // admin.serialize(ref calldata);
        // init_token.serialize(ref calldata);
        // (2 * initial_key_price).serialize(ref calldata);

        // let init_token= {
        //     token_address: token_address,
        //     initial_key_price,
        //     price: initial_key_price,
        //     pub is_enable: true
        // };

        // calldata.append_serde(admin);
        calldata.append_serde(initial_key_price);
        calldata.append_serde(token_address);
        // calldata.append_serde(initial_key_price);


        let (contract_address, _) = class.deploy(@calldata).unwrap();

        IKeysMarketplaceDispatcher { contract_address }
    }


    // fn deploy_marketplace(
    //     class: ContractClass,
    //     admin: ContractAddress,
    //     init_token: TokenQuoteBuyKeys,
    //     initial_key_price: u256
    // ) -> IKeysMarketplaceDispatcher {
    //     let mut calldata = array![];

    //     println!("deploy marketplace");
    //     admin.serialize(ref calldata);
    //     init_token.serialize(ref calldata);
    //     // (2 * initial_key_price).serialize(ref calldata);

    //     calldata.append_serde(admin);
    //     calldata.append_serde(init_token);
    //     // calldata.append_serde(initial_key_price);


    //     let (contract_address, _) = class.deploy(@calldata).unwrap();

    //     IKeysMarketplaceDispatcher { contract_address }
    // }

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
        let ( sender_address, erc20, keys) = request_fixture();
        // let ( sender_address, erc20) = request_fixture();
        // let recipient_address: ContractAddress = 345.try_into().unwrap();
        // let amount = 100_u256;

        // cheat_caller_address_global(sender_address);
        // erc20.approve(keys.contract_address, amount + amount);
        // stop_cheat_caller_address_global();

        // start_cheat_caller_address(keys.contract_address, sender_address);
    // keys.deposit(amount, erc20.contract_address, recipient_nostr_key, 0_u64);

    // start_cheat_caller_address(escrow.contract_address, recipient_address);
    // keys.claim(request);
    }
}
