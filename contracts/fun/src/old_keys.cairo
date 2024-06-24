use core::num::traits::Zero;
use joy_fun::keys_types::{
    //    TokenQuoteBuyKeys, Keys, SharesKeys, BondingType, 
    KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE, StoredName, BuyKeys, SellKeys,
    CreateKeys, KeysUpdated, TokenQuoteBuyKeys, Keys, SharesKeys, BondingType, get_linear_price,
};
// use array::ArrayTrait;

use starknet::ContractAddress;


#[starknet::interface]
pub trait IKeysMarketplace<TContractState> {
    fn set_token(ref self: TContractState, token_quote: TokenQuoteBuyKeys);
    fn set_protocol_fee_percent(ref self: TContractState, protocol_fee_percent: u256);
    fn set_creator_fee_percent(ref self: TContractState, creator_fee_percent: u256);
    fn set_protocol_fee_destination(
        ref self: TContractState, protocol_fee_destination: ContractAddress
    );
    fn store_name(
        ref self: TContractState,
        name: felt252, // bonding_type: KeysMarketplace::BondingType
        bonding_type: BondingType
    );
    fn instantiate_keys(
        ref self: TContractState, // token_quote: TokenQuoteBuyKeys, // bonding_type: KeysMarketplace::BondingType,
    );
    fn buy_keys(ref self: TContractState, address_user: ContractAddress, amount: u256);
    fn sell_keys(ref self: TContractState, address_user: ContractAddress, amount: u256);
    fn get_default_token(self: @TContractState,) -> TokenQuoteBuyKeys;
    fn get_next_price(
        self: @TContractState,
        address_user: ContractAddress,
        amount: u256,
        bonding_type: BondingType
    ) -> TokenQuoteBuyKeys;
    fn get_amount_to_paid(
        self: @TContractState, address_user: ContractAddress, amount: u256,
    // supply:u256,
    // bonding_type: BondingType,
    // token_quote: TokenQuoteBuyKeys
    ) -> u256;
    fn get_key_of_user(self: @TContractState, key_user: ContractAddress,) -> Keys;
    fn get_share_key_of_user(
        self: @TContractState, owner: ContractAddress, key_user: ContractAddress,
    ) -> SharesKeys;

    fn get_all_keys(self: @TContractState) -> Span<Keys>;
}

#[starknet::contract]
mod KeysMarketplace {
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
        KeysBonding, KeysBondingImpl, MINTER_ROLE, ADMIN_ROLE, BondingType, get_linear_price,
    };
    const MIN_FEE: u256 = 10; //0.1%
    const MAX_FEE: u256 = 1000; //10%
    const MID_FEE: u256 = 100; //1%

    const MIN_FEE_CREATOR: u256 = 100; //1%
    const MID_FEE_CREATOR: u256 = 1000; //10%
    const MAX_FEE_CREATOR: u256 = 5000; //50%

    const BPS: u256 = 10_000; // 100% = 10_000 bps


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
        bonding_type: LegacyMap::<ContractAddress, BondingType>,
        array_keys_of_users: LegacyMap::<u64, Keys>,
        total_names: u128,
        initial_key_price: u256,
        protocol_fee_percent: u256,
        creator_fee_percent: u256,
        is_fees_protocol: bool,
        step_increase_linear: u256,
        is_tokens_buy_enable: LegacyMap::<ContractAddress, TokenQuoteBuyKeys>,
        default_token: TokenQuoteBuyKeys,
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
        step_increase_linear: u256
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
        self.creator_fee_percent.write(MAX_FEE_CREATOR);
        self.step_increase_linear.write(step_increase_linear);
        self.total_keys.write(0);
    //    self.protocol_fee_percent.write(MID_FEE);
    //  self.creator_fee_percent.write(MIN_FEE_CREATOR);
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

            assert(creator_fee_percent < MAX_FEE_CREATOR, 'creator_fee_too_high');
            assert(creator_fee_percent > MIN_FEE_CREATOR, 'creator_fee_too_low');

            self.creator_fee_percent.write(creator_fee_percent);
        }

        fn store_name(ref self: ContractState, name: felt252, bonding_type: BondingType) {
            let caller = get_caller_address();
            self._store_name(caller, name, bonding_type);
        }

        // User

        // Create keys for an user
        fn instantiate_keys(ref self: ContractState, // token_quote: TokenQuoteBuyKeys,
        // bonding_type: BondingType, 
        ) {
            let caller = get_caller_address();
            let keys = self.keys_of_users.read(caller);
            assert!(keys.owner.is_zero(), "key already created");
            let initial_key_price = self.initial_key_price.read();

            let mut token_to_use = self.default_token.read();
            // Todo function with custom init token
            // if self.is_custom_token_enable.read() {
            //     token_to_use = token_quote;
            // }
            // let bond_type = BondingType::Degens(10);
            let bond_type = BondingType::Linear;

            // @TODO Deploy an ERC404
            // Option for liquidity providing and Trading
            let key = Keys {
                owner: caller,
                token_address: caller, // CREATE 404
                price: initial_key_price,
                total_supply: 1,
                // Todo price by pricetype after fix Enum instantiate
                bonding_curve_type: Option::Some(bond_type),
                // bonding_curve_type: BondingType,
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
                total_paid: 0
            };
            self.shares_by_users.write((get_caller_address(), get_caller_address()), share_user);
            self.keys_of_users.write(get_caller_address(), key.clone());

            let total_key = self.total_keys.read();
            if total_key == 0 {
                 self.total_keys.write(1);
            self.array_keys_of_users.write(0, key);
            } else {
                self.total_keys.write(total_key + 1);
                self.array_keys_of_users.write(total_key , key);
            }

            self
                .emit(
                    CreateKeys {
                        caller: get_caller_address(),
                        key_user: get_caller_address(),
                        amount: 1,
                        price: 1,
                    }
                );
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
            let token_quote = old_keys.token_quote.clone();
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
                total_supply: old_keys.total_supply,
                bonding_curve_type: old_keys.bonding_curve_type,
            };
            // Todo price by pricetype after fix Enum instantiate
            // Refactorize and opti
            let mut actual_supply = total_supply;
            let final_supply = total_supply + amount;
            let current_price = key.price.clone();
            let mut price = current_price;
            let mut total_price = price;
            let initial_key_price = token_quote.initial_key_price;
            let step_increase_linear = token_quote.step_increase_linear;

            // Naive loop for price calculation
            // Add calculation curve

            let result = loop {
                println!("token_quote.initial_key_price {}", token_quote.initial_key_price);
                // Bonding price calculation based on a type 
                let current_price = initial_key_price + (actual_supply * step_increase_linear);
                println!("current_price {}", current_price);

                println!("token_quote.initial_key_price {}", token_quote.initial_key_price);
                if final_supply == actual_supply {
                    break total_price;
                }
                // OLD calculation
                // let price_for_this_key = actual_supply * token_quote.initial_key_price;
                // let price_for_this_key = initial_key_price* (actual_supply * step_increase_linear);
                // let price_for_this_key=get_linear_price(key, actual_supply);
                // let price_for_this_key=get_linear_price(key.clone(), actual_supply);
                let price_for_this_key = KeysBonding::get_price(key.clone(), actual_supply);

                println!("i {} price_for_this_key {}", actual_supply, price_for_this_key);
                price += price_for_this_key;
                total_price += price_for_this_key;
                println!("i {} total_price {}", actual_supply, total_price);

                actual_supply += 1;
            };
            println!("total_price {}", total_price.clone());
            println!("protocol_fee_percent {}", protocol_fee_percent);
            let amount_protocol_fee: u256 = total_price * protocol_fee_percent / BPS;
            println!("amount_protocol_fee {}", amount_protocol_fee.clone());
            // total_price-=amount_protocol_fee;
            let amount_creator_fee = total_price * creator_fee_percent / BPS;
            println!("amount_creator_fee {}", amount_creator_fee.clone());

            let remain_liquidity = total_price - amount_creator_fee - amount_protocol_fee;
            println!("remain_liquidity {}", remain_liquidity.clone());

            let mut old_share = self.shares_by_users.read((get_caller_address(), address_user));

            let mut share_user = old_share.clone();
            if old_share.owner.is_zero() {
                share_user =
                    SharesKeys {
                        owner: get_caller_address(),
                        key_address: address_user,
                        amount_owned: amount,
                        amount_buy: amount,
                        amount_sell: 0,
                        created_at: get_block_timestamp(),
                        total_paid: total_price,
                    };
                let total_key_share = self.total_shares_keys.read();
                self.total_shares_keys.write(total_key_share + 1);
            } else {
                share_user.total_paid += total_price;
                share_user.amount_owned += amount;
            }
            key.price = total_price;
            key.total_supply += amount;
            self.shares_by_users.write((get_caller_address(), address_user), share_user.clone());

            self.keys_of_users.write(address_user, key.clone());

            // Transfer to Liquidity, Creator and Protocol

            println!("transfer protocol fee {}", amount_protocol_fee.clone());

            // TODO uncomment after allowance check script
            erc20
                .transfer_from(
                    get_caller_address(), self.protocol_fee_destination.read(), amount_protocol_fee
                );

            erc20.transfer_from(get_caller_address(), key.owner, amount_creator_fee);

            println!("transfer liquidity {}", remain_liquidity.clone());
            erc20.transfer_from(get_caller_address(), get_contract_address(), remain_liquidity);

            self
                .emit(
                    BuyKeys {
                        caller: get_caller_address(),
                        key_user: address_user,
                        amount: amount,
                        price: total_price,
                        protocol_fee: amount_protocol_fee,
                        creator_fee: amount_creator_fee
                    }
                );
        }

        fn sell_keys(ref self: ContractState, address_user: ContractAddress, amount: u256) {
            let old_keys = self.keys_of_users.read(address_user);
            assert!(!old_keys.owner.is_zero(), "key not found");
            let initial_key_price = self.initial_key_price.read();

            let mut old_share = self.shares_by_users.read((get_caller_address(), address_user));

            let mut share_user = old_share.clone();
            // Verify Amount owned

            assert!(old_share.amount_owned >= amount, "share too low");
            assert!(old_keys.total_supply >= amount, "above supply");

            // TODO erc20 token transfer
            let token = old_keys.token_quote.clone();
            let key_token_address = old_keys.token_address;
            let total_supply = old_keys.total_supply;
            let token_quote = old_keys.token_quote.clone();
            let quote_token_address = token_quote.token_address.clone();

            let erc20 = IERC20Dispatcher { contract_address: quote_token_address };
            let amount_transfer = token.initial_key_price;
            let protocol_fee_percent = self.protocol_fee_percent.read();
            let creator_fee_percent = self.creator_fee_percent.read();

            assert!(old_keys.total_supply >= amount, "share > supply");

            // Update keys with new values
            let mut key = Keys {
                owner: old_keys.owner,
                token_address: key_token_address, // CREATE 404
                created_at: old_keys.created_at,
                token_quote: token,
                price: old_keys.price,
                initial_key_price: token_quote.initial_key_price,
                total_supply: old_keys.total_supply,
                bonding_curve_type: old_keys.bonding_curve_type,
            };
            // Todo price by pricetype after fix Enum instantiate
            // Refactorize and opti
            let mut actual_supply = total_supply;
            let final_supply = total_supply - amount;
            let current_price = key.price.clone();
            let mut price = current_price;
            let mut total_price = price;
            let initial_key_price = token_quote.initial_key_price;
            let step_increase_linear = token_quote.step_increase_linear;

            // Naive loop for price calculation
            // Add calculation curve
            println!("actual_supply {} ", actual_supply);
            println!("final_supply {} ", final_supply);

            let result = loop {
                println!("token_quote.initial_key_price {}", token_quote.initial_key_price);
                let current_price = initial_key_price + (actual_supply * step_increase_linear);
                println!("current_price {}", current_price);

                if final_supply == actual_supply {
                    key.price = current_price;

                    break total_price;
                }
                // Bonding price calculation based on a type 
                // OLD calculation
                // let price_for_this_key = initial_key_price* (actual_supply * step_increase_linear);
                // let price_for_this_key=get_linear_price(key.clone(), actual_supply);
                let price_for_this_key = KeysBonding::get_price(key.clone(), actual_supply);

                println!("i {} price_for_this_key {}", actual_supply, price_for_this_key);
                price -= price_for_this_key;
                total_price -= price_for_this_key;
                println!("i {} total_price {}", actual_supply, total_price);

                actual_supply -= 1;
            };

            println!("total_price {}", total_price.clone());
            println!("protocol_fee_percent {}", protocol_fee_percent);
            let amount_protocol_fee: u256 = total_price * protocol_fee_percent / BPS;
            println!("amount_protocol_fee {}", amount_protocol_fee.clone());
            // total_price-=amount_protocol_fee;
            let amount_creator_fee = total_price * creator_fee_percent / BPS;
            println!("amount_creator_fee {}", amount_creator_fee.clone());

            let remain_liquidity = total_price - amount_creator_fee - amount_protocol_fee;
            println!("remain_liquidity {}", remain_liquidity.clone());

            if old_share.owner.is_zero() {
                share_user =
                    SharesKeys {
                        owner: get_caller_address(),
                        key_address: address_user,
                        amount_owned: amount,
                        amount_buy: amount,
                        amount_sell: amount,
                        created_at: get_block_timestamp(),
                        total_paid: total_price,
                    };
            } else {
                println!("Amount owned {}", share_user.amount_owned);
                println!("Decrease amount {}", amount);

                share_user.total_paid += total_price;
                share_user.amount_owned -= amount;
                share_user.amount_sell += amount;
            }
            // key.price = total_price;
            key.total_supply -= amount;
            self.shares_by_users.write((get_caller_address(), address_user), share_user.clone());
            self.keys_of_users.write(address_user, key.clone());

            // Transfer to Liquidity, Creator and Protocol

            println!("transfer protocol fee {}", amount_protocol_fee.clone());

            erc20.transfer(self.protocol_fee_destination.read(), amount_protocol_fee);
            println!("transfer creator fee {}", amount_creator_fee.clone());

            erc20.transfer(key.owner, amount_creator_fee);

            println!("transfer liquidity {}", remain_liquidity.clone());
            erc20.transfer(get_caller_address(), remain_liquidity);

            self
                .emit(
                    SellKeys {
                        caller: get_caller_address(),
                        key_user: address_user,
                        amount: amount,
                        price: total_price,
                        protocol_fee: amount_protocol_fee,
                        creator_fee: amount_creator_fee
                    }
                );
        }

        fn get_default_token(self: @ContractState) -> TokenQuoteBuyKeys {
            self.default_token.read()
        }

        fn get_next_price(
            self: @ContractState,
            address_user: ContractAddress,
            amount: u256,
            // supply: u256,
            bonding_type: BondingType
        ) -> TokenQuoteBuyKeys {
            self.default_token.read()
        }

        fn get_amount_to_paid(
            self: @ContractState, address_user: ContractAddress, amount: u256,
        // supply:u256, 
        // bonding_type: BondingType,
        // token_quote: TokenQuoteBuyKeys
        ) -> u256 {
            let key = self.keys_of_users.read(address_user);
            let mut total_supply = key.total_supply;
            let mut actual_supply = total_supply;
            let final_supply = total_supply - amount;
            let current_price = key.price.clone();
            let mut price = current_price;
            let mut total_price = price;
            let token_quote = key.token_quote.clone();
            let initial_key_price = token_quote.initial_key_price;
            let step_increase_linear = token_quote.step_increase_linear;
            let result = loop {
                // Bonding price calculation based on a type 
                let current_price = initial_key_price + (actual_supply * step_increase_linear);
                println!("current_price {}", current_price);

                println!("token_quote.initial_key_price {}", token_quote.initial_key_price);
                if final_supply == actual_supply {
                    break total_price;
                }
                // OLD calculation
                // let price_for_this_key = initial_key_price * (actual_supply * step_increase_linear);
                // get_amount_to_paid
                let price_for_this_key = KeysBonding::get_price(key.clone(), actual_supply);

                println!("i {} price_for_this_key {}", actual_supply, price_for_this_key);
                price += price_for_this_key;
                total_price += price_for_this_key;
                println!("i {} total_price {}", actual_supply, total_price);

                actual_supply -= 1;
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
            let max_key_id = self.total_keys.read()+1;
            let mut keys: Array<Keys> = ArrayTrait::new();
            let mut i = 0; //Since the stream id starts from 0
            loop {
                if i >= max_key_id {
                }
                let key = self.array_keys_of_users.read(i);
                if key.owner.is_zero() {
                    break keys.span();
                }
                keys.append(key);
                i += 1;
            }
        }
    // fn get_all_shares_keys(
    //     self: @ContractState
    // ) -> Span<SharesKeys> {
    //     self.shares_by_users.read()
    // }
    }

    // Could be a group of functions about a same topic
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _store_name(
            ref self: ContractState, user: ContractAddress, name: felt252, bonding_type: BondingType
        ) { // let total_names = self.total_names.read();
        // self.names.write(user, name);
        // self.bonding_type.write(user, bonding_type);
        // self.total_names.write(total_names + 1);
        // self.emit(StoredName { user: user, name: name });
        }

        fn _update_keys(
            ref self: ContractState, user: ContractAddress, keys: Keys,
        // name: felt252,
        // bonding_type: BondingType
        ) { // let total_names = self.total_names.read();
        // self.names.write(user, name);
        // self.bonding_type.write(user, bonding_type);
        // self.total_names.write(total_names + 1);
        // self.emit(StoredName { user: user, name: name });
        }
    }
}
