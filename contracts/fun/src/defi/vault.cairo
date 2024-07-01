use joy_fun::types::keys_types::{
    KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE, StoredName, BuyKeys, SellKeys,
    CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys, BondingType, get_linear_price,
};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVaultInterface<TContractState> {
    fn set_token(ref self: TContractState, token_quote: TokenQuoteBuyKeys);
    fn set_protocol_fee_percent(ref self: TContractState, protocol_fee_percent: u256);
    fn set_creator_fee_percent(ref self: TContractState, creator_fee_percent: u256);
    fn set_protocol_fee_destination(
        ref self: TContractState, protocol_fee_destination: ContractAddress
    );
    fn get_default_token(self: @TContractState,) -> TokenQuoteBuyKeys;
    fn get_amount_to_paid(
        self: @TContractState, address_user: ContractAddress, amount: u256,
    ) -> u256;
    fn get_key_of_user(self: @TContractState, key_user: ContractAddress,) -> Keys;
    fn get_share_key_of_user(
        self: @TContractState, owner: ContractAddress, key_user: ContractAddress,
    ) -> SharesKeys;
    fn get_all_keys(self: @TContractState) -> Span<Keys>;
}

#[starknet::contract]
mod Vault {
    use core::num::traits::Zero;
    use joy_fun::erc20::{ERC20, IERC20Dispatcher, IERC20DispatcherTrait};


    use openzeppelin::access::accesscontrol::{AccessControlComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        contract_address_const, get_block_timestamp, get_contract_address,
    };
    use super::{
        StoredName, BuyKeys, SellKeys, CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys,
        KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE, BondingType,
    };

    // Params
    const MAX_STEPS_LOOP: u256 = 100;

    const BPS: u256 = 10_000; // 100% = 10_000 bps

    // Fees 
    const MIN_FEE: u256 = 10; //0.1%
    const MAX_FEE: u256 = 1000; //10%
    const MID_FEE: u256 = 100; //1%


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
        oracle_address: ContractAddress,
        is_assets_enabled: LegacyMap::<ContractAddress, bool>,
        assets_by_felt: LegacyMap::<felt252, ContractAddress>,
        names: LegacyMap::<ContractAddress, felt252>,
        keys_of_users: LegacyMap::<ContractAddress, Keys>,
        shares_by_users: LegacyMap::<(ContractAddress, ContractAddress), SharesKeys>,
        array_keys_of_users: LegacyMap::<u64, Keys>,
        is_tokens_buy_enable: LegacyMap::<ContractAddress, TokenQuoteBuyKeys>,
        default_token: TokenQuoteBuyKeys,
        total_names: u128,
        initial_key_price: u256,
        protocol_fee_percent: u256,
        creator_fee_percent: u256,
        is_fees_protocol: bool,
        step_increase_linear: u256,
        is_custom_key_enable: bool,
        is_custom_token_enable: bool,
        protocol_fee_destination: ContractAddress,
        total_keys: u64,
        total_shares_keys: u64,
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
        token_address: ContractAddress,
        step_increase_linear: u256,
    ) {
        // AccessControl-related initialization
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(MINTER_ROLE, admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin);

        let init_token = TokenQuoteBuyKeys {
            token_address: token_address,
            initial_key_price,
            price: initial_key_price,
            is_enable: true,
            step_increase_linear
        };
        self.is_custom_key_enable.write(false);
        self.is_custom_token_enable.write(false);
        self.default_token.write(init_token.clone());
        self.initial_key_price.write(init_token.initial_key_price);

        self.protocol_fee_destination.write(admin);
        self.protocol_fee_percent.write(MAX_FEE);
        self.step_increase_linear.write(step_increase_linear);
        self.total_keys.write(0);
    }

    // Public functions inside an impl block
    #[abi(embed_v0)]
    impl Vault of super::IVaultInterface<ContractState> {
        // ADMIN
        fn set_token(ref self: ContractState, token_quote: TokenQuoteBuyKeys) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.is_tokens_buy_enable.write(token_quote.token_address, token_quote);
        }
        fn set_protocol_fee_percent(ref self: ContractState, protocol_fee_percent: u256) {
            let caller = get_caller_address();
            assert(protocol_fee_percent < MAX_FEE, 'protocol_fee_too_high');
            assert(protocol_fee_percent > MIN_FEE, 'protocol_fee_too_low');

            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.protocol_fee_percent.write(protocol_fee_percent);
        }
        fn set_protocol_fee_destination(
            ref self: ContractState, protocol_fee_destination: ContractAddress
        ) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.protocol_fee_destination.write(protocol_fee_destination);
        }

        fn set_creator_fee_percent(ref self: ContractState, creator_fee_percent: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            assert(creator_fee_percent < MAX_FEE, 'creator_fee_too_high');
            assert(creator_fee_percent > MIN_FEE, 'creator_fee_too_low');

            self.creator_fee_percent.write(creator_fee_percent);
        }

        // Getters
        fn get_default_token(self: @ContractState) -> TokenQuoteBuyKeys {
            self.default_token.read()
        }

        fn get_amount_to_paid(
            self: @ContractState, address_user: ContractAddress, amount: u256,
        ) -> u256 {
            assert!(amount <= MAX_STEPS_LOOP, "max step loop");
            let key = self.keys_of_users.read(address_user);
            let mut total_supply = key.total_supply;
            let mut actual_supply = total_supply;
            let final_supply = total_supply - amount;
            let token_quote = key.token_quote.clone();

            let mut actual_supply = total_supply;
            let final_supply = total_supply + amount;
            let mut price = key.price.clone();
            let mut total_price = price;
            let initial_key_price = token_quote.initial_key_price.clone();
            let step_increase_linear = token_quote.step_increase_linear.clone();

            // Naive loop for price calculation
            // Add calculation curve
            loop {
                // Bonding price calculation based on a type 
                if final_supply == actual_supply {
                    // break total_price;
                    break;
                }
                // OLD calculation
                let price_for_this_key = KeysBonding::get_price(key, actual_supply);
                price += price_for_this_key;
                total_price += price_for_this_key;
                actual_supply += 1;
            };

            total_price
        }

        fn get_key_of_user(self: @ContractState, key_user: ContractAddress,) -> Keys {
            self.keys_of_users.read(key_user)
        }

        fn get_share_key_of_user(
            self: @ContractState, owner: ContractAddress, key_user: ContractAddress,
        ) -> SharesKeys {
            self.shares_by_users.read((owner, key_user))
        }

        fn get_all_keys(self: @ContractState) -> Span<Keys> {
            let max_key_id = self.total_keys.read() + 1;
            let mut keys: Array<Keys> = ArrayTrait::new();
            let mut i = 0; //Since the stream id starts from 0
            loop {
                if i >= max_key_id {}
                let key = self.array_keys_of_users.read(i);
                if key.owner.is_zero() {
                    break keys.span();
                }
                keys.append(key);
                i += 1;
            }
        }
    }

    // // Could be a group of functions about a same topic
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _loop_get_price_for_each_key(
            price: u256, key: Keys, supply: u256, amount: u256
        ) -> u256 {
            let mut total_supply = key.total_supply.clone();
            let mut actual_supply = total_supply;
            let token_quote = key.token_quote.clone();
            let final_supply = total_supply + amount;
            let mut price = key.price.clone();
            let mut total_price = price;
            let initial_key_price = token_quote.initial_key_price.clone();
            let step_increase_linear = token_quote.step_increase_linear.clone();
            loop {
                // Bonding price calculation based on a type 
                if final_supply == actual_supply {
                    break;
                }
                // OLD calculation
                let price_for_this_key = KeysBonding::get_price(key, actual_supply);
                price += price_for_this_key;
                total_price += price_for_this_key;
                actual_supply += 1;
            };

            total_price
        }
    }
}
