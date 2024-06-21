use core::num::traits::Zero;
use starknet::ContractAddress;
use joy_fun::keys_types::{
        StoredName, BuyKeys, SellKeys, CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys,
        BondingType, KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE,
        get_current_price
};


#[starknet::interface]
pub trait IKeysMarketplace<TContractState> {
    fn set_token(ref self: TContractState, token_quote: TokenQuoteBuyKeys);
    fn set_protocol_fee_percent(ref self: TContractState, protocol_fee_percent: u256);
    fn set_creator_fee_percent(ref self: TContractState, creator_fee_percent: u256);
    fn set_protocol_fee_destination(ref self: TContractState, protocol_fee_destination: ContractAddress);
    fn store_name(
        ref self: TContractState,
        name: felt252, // registration_type: KeysMarketplace::BondingType
        registration_type: BondingType
    );
    fn instantiate_keys(
        ref self: TContractState,
        // token_quote: TokenQuoteBuyKeys, // registration_type: KeysMarketplace::BondingType,
    );
    fn buy_keys(ref self: TContractState, address_user: ContractAddress, amount: u256);
    fn sell_keys(ref self: TContractState, amount: u256);
    fn get_default_token(self: @TContractState,) -> TokenQuoteBuyKeys;
    // fn get_owner(self: @TContractState) -> KeysMarketplace::Person;
}

#[starknet::contract]
mod KeysMarketplace {
    const MIN_FEE: u256 = 10; //0.1%
    const MAX_FEE: u256 = 1000; //10%
    const MID_FEE: u256 = 100; //1%

    const MIN_FEE_CREATOR: u256 = 100; //1%
    const MID_FEE_CREATOR: u256 = 1000; //10%
    const MAX_FEE_CREATOR: u256 = 5000; //50%

    const BPS: u256 = 10_000; // 100% = 10_000 bps
    use core::num::traits::Zero;
    use super::{
        StoredName, BuyKeys, SellKeys, CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys,
        BondingType, KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE,
        get_current_price
    };
    use openzeppelin::access::accesscontrol::{AccessControlComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    use joy_fun::erc20::{ERC20,  IERC20Dispatcher, IERC20DispatcherTrait};
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
        creator_fee_percent: u256,
        is_fees_protocol: bool,
        is_tokens_buy_enable: LegacyMap::<ContractAddress, TokenQuoteBuyKeys>,
        default_token: TokenQuoteBuyKeys,
        is_custom_key_enable: bool,
        is_custom_token_enable: bool,
        protocol_fee_destination: ContractAddress,
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
        self.is_custom_key_enable.write(false);
        self.is_custom_token_enable.write(false);
        self.default_token.write(init_token.clone());
        self.initial_key_price.write(init_token.initial_key_price);
        // self.protocol_fee_percent.write(MAX_FEE);
        self.protocol_fee_percent.write(MID_FEE);
        self.creator_fee_percent.write(MID_FEE);
        self.protocol_fee_destination.write(admin);
    }

  
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
            assert(protocol_fee_percent < MAX_FEE, 'protocol_fee_too_high');
            assert(protocol_fee_percent > MIN_FEE, 'protocol_fee_too_low');

            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.protocol_fee_percent.write(protocol_fee_percent);
        }

        fn set_protocol_fee_destination(ref self: ContractState, protocol_fee_destination: ContractAddress) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.protocol_fee_destination.write(protocol_fee_destination);
        }

        

        fn set_creator_fee_percent(ref self: ContractState, creator_fee_percent: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            assert(creator_fee_percent < MAX_FEE_CREATOR, 'creator_fee_too_high');
            assert(creator_fee_percent > MIN_FEE_CREATOR, 'creator_fee_too_low');

            self.creator_fee_percent.write(creator_fee_percent);
        }

        fn store_name(ref self: ContractState, name: felt252, registration_type: BondingType) {
            let caller = get_caller_address();
            self._store_name(caller, name, registration_type);
        }

        // User

        // Create keys for an user
        fn instantiate_keys(
            ref self: ContractState,
            // token_quote: TokenQuoteBuyKeys,
             // registration_type: BondingType, 
        ) {
            let caller = get_caller_address();
            let keys = self.keys_of_users.read(caller);
            assert!(keys.owner.is_zero(), "key already created");
            let initial_key_price = self.initial_key_price.read();

            let mut token_to_use = self.default_token.read();
            // if self.is_custom_token_enable.read() {
            //     token_to_use = token_quote;
            // }
            let key = Keys {
                owner: caller,
                token_address: caller, // CREATE 404
                price: initial_key_price,
                total_supply: 1,
                // Todo price by pricetype after fix Enum instantiate
                // bonding_curve_type: BondingType::Basic,
                created_at: get_block_timestamp(),
                token_quote: token_to_use.clone(),
                initial_key_price: token_to_use.initial_key_price,

            };

            let share_user = SharesKeys {
                owner: get_caller_address(),
                key_address: get_caller_address(),
                amount_owned: 1,
                amount_buy: 1,
                amount_sell: 0,
                created_at: get_block_timestamp(),
                total_paid:0
            };
            self.shares_by_users.write((get_caller_address(), get_caller_address()), share_user);
            self.keys_of_users.write(get_caller_address(), key);
        }

        fn buy_keys(ref self: ContractState, address_user: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let old_keys = self.keys_of_users.read(address_user);
            assert!(!old_keys.owner.is_zero(), "key not found");
            let initial_key_price = self.initial_key_price.read();

            // TODO erc20 token transfer
            let token = old_keys.token_quote.clone();
            let key_token_address = old_keys.token_address;
            // let bonding_curve_type = old_keys.bonding_curve_type;
            let total_supply = old_keys.total_supply;
            let token_quote=old_keys.token_quote.clone();
            let quote_token_address = token_quote.token_address.clone();

            let erc20 = IERC20Dispatcher { contract_address: quote_token_address };
            let amount_transfer = token.initial_key_price;
            let protocol_fee_percent = self.protocol_fee_percent.read();
            let creator_fee_percent = self.creator_fee_percent.read();

            // Update keys with new values
            let mut key = Keys {
                owner: old_keys.owner,
                token_address: key_token_address, // CREATE 404
                created_at: old_keys.created_at,
                token_quote: token,
                price: old_keys.price,
                initial_key_price: token_quote.initial_key_price,
                total_supply: total_supply + amount,
                // bonding_curve_type: bonding_curve_type,
            };
            // Todo price by pricetype after fix Enum instantiate
            // Refactorize and opti
            let mut actual_supply=total_supply;
            let final_supply=total_supply+amount;
            let current_price = key.price.clone();
            let mut price = current_price;
            let mut total_price = price;
            let initial_key_price = token_quote.initial_key_price;

            // Naive loop for price calculation
            // Add calculation curve

            let result = loop {
                println!("token_quote.initial_key_price {}", token_quote.initial_key_price);
                if final_supply == actual_supply {
                    break total_price;
                }
                // Bonding price calculation based on a type 
                let current_price= initial_key_price+ (actual_supply*initial_key_price);
                println!("current_price {}", current_price);
                // OLD calculation
                // let price_for_this_key = actual_supply* token_quote.initial_key_price;
                let price_for_this_key = actual_supply* token_quote.initial_key_price;
                // let price_for_this_key = current_price* (actual_supply *token_quote.initial_key_price);
                println!("i {} price_for_this_key {}", actual_supply, price_for_this_key);
                price+=price_for_this_key;
                total_price+=price_for_this_key;
                println!("i {} total_price {}", actual_supply, total_price);

                actual_supply += 1;
            };
            println!("total_price {}", total_price.clone());
            println!("protocol_fee_percent {}", protocol_fee_percent);
            let amount_protocol_fee:u256 = total_price*protocol_fee_percent/BPS;
            println!("amount_protocol_fee {}", amount_protocol_fee.clone());
            // total_price-=amount_protocol_fee;
            let amount_creator_fee=total_price*creator_fee_percent/BPS;
            println!("amount_creator_fee {}", amount_creator_fee.clone());

            let remain_liquidity= total_price-amount_creator_fee-amount_protocol_fee;
            println!("remain_liquidity {}", remain_liquidity.clone());

            let mut old_share = self
                .shares_by_users
                .read((get_caller_address(), address_user));

            let mut share_user=old_share.clone();
            if old_share.owner.is_zero() {
                share_user=SharesKeys {
                    owner:get_caller_address(),
                    key_address:address_user,
                    amount_owned:amount,
                    amount_buy:amount,
                    amount_sell:0,
                    created_at:get_block_timestamp(),
                    total_paid:total_price,
                };
            } else {
                share_user.total_paid+=total_price;
                share_user.amount_owned+=amount;
            }
            key.price = total_price;
            key.total_supply=amount+total_supply;
            self.shares_by_users.write((get_caller_address(), address_user), share_user.clone());

            // Transfer to Liquidity, Creator and Protocol
    
            println!("transfer protocol fee {}", amount_protocol_fee.clone());

            erc20.transfer_from(get_caller_address(),  self.protocol_fee_destination.read(), amount_protocol_fee);
            println!("transfer creator fee {}", amount_creator_fee.clone());

            erc20.transfer_from(get_caller_address(), key.owner, amount_creator_fee);

            println!("transfer liquidity {}", remain_liquidity.clone());
            erc20.transfer_from(get_caller_address(), get_contract_address(), remain_liquidity);

            self.emit(BuyKeys{caller:get_caller_address(), key_user:address_user, amount:amount, price:total_price, protocol_fee:amount_protocol_fee, creator_fee:amount_creator_fee});
            
        }

        fn sell_keys(ref self: ContractState, amount: u256) { 
            // let caller = get_caller_address();
            // self._update_keys(caller, name, registration_type);
        }

        fn get_default_token(self: @ContractState) -> TokenQuoteBuyKeys {
            self.default_token.read()
        }
    }

    // Could be a group of functions about a same topic
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _store_name(
            ref self: ContractState,
            user: ContractAddress,
            name: felt252,
            registration_type: BondingType
        ) { 
            // let total_names = self.total_names.read();
            // self.names.write(user, name);
            // self.registration_type.write(user, registration_type);
            // self.total_names.write(total_names + 1);
            // self.emit(StoredName { user: user, name: name });
        }

        fn _update_keys(
            ref self: ContractState, 
            user: ContractAddress, 
            keys: Keys, 
            // name: felt252,
            // registration_type: BondingType
        ) { // let total_names = self.total_names.read();
            // self.names.write(user, name);
            // self.registration_type.write(user, registration_type);
            // self.total_names.write(total_names + 1);
            // self.emit(StoredName { user: user, name: name });
        }

    }

}
