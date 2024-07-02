use joy_fun::types::defi_types::{
    MINTER_ROLE, ADMIN_ROLE, OPERATOR_ROLE, TokenQuoteBuyKeys, Deposit, AssetPool, 
    // get_linear_price,
    DepositTokenEvent, WithdrawTokenEvent, StakeTokenEvent,
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
    // fn get_amount_to_paid(
    //     self: @TContractState, address_user: ContractAddress, amount: u256,
    // ) -> u256;
    // fn get_key_of_user(self: @TContractState, key_user: ContractAddress,) -> Keys;
    // fn get_share_key_of_user(
    //     self: @TContractState, owner: ContractAddress, key_user: ContractAddress,
    // ) -> SharesKeys;
    // fn get_all_assets(self: @TContractState) -> Span<AssetPool>;
}

#[starknet::contract]
mod Vault {
    use core::num::traits::Zero;
    use joy_fun::tokens::erc20::{ERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    // use joy_fun::tokens::ERC20::{ERC20, IERC20Dispatcher, IERC20DispatcherTrait};


    use openzeppelin::access::accesscontrol::{AccessControlComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        contract_address_const, get_block_timestamp, get_contract_address,
    };
    use super::{
        TokenQuoteBuyKeys, Deposit, AssetPool, MINTER_ROLE, ADMIN_ROLE, OPERATOR_ROLE,
        DepositTokenEvent, StakeTokenEvent, WithdrawTokenEvent
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
        is_tokens_buy_enable: LegacyMap::<ContractAddress, TokenQuoteBuyKeys>,
        default_token: TokenQuoteBuyKeys,
        oracle_address: ContractAddress,
        is_assets_enabled: LegacyMap::<ContractAddress, bool>,
        assets_by_felt: LegacyMap::<felt252, ContractAddress>,
        names: LegacyMap::<ContractAddress, felt252>,
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
        DepositTokenEvent: DepositTokenEvent,
        WithdrawTokenEvent: WithdrawTokenEvent,
        StakeTokenEvent: StakeTokenEvent,
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
    }

    // // Could be a group of functions about a same topic
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _get_price(amount: u256) -> u256 {
            amount
        }
    }
}
