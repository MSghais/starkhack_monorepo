use starknet::ContractAddress;

#[starknet::interface]
pub trait IKeysMarketplace<TContractState> {

    fn set_token( ref self: TContractState, token_quote:TokenQuoteBuyKeys );
    fn set_protocol_fee_percent( ref self: TContractState, protocol_fee_percent:u256 );
    fn set_creator_fee( ref self: TContractState, creator_fees:u256 );
    fn store_name(
        ref self: TContractState, name: felt252, registration_type: KeysMarketplace::BondingType
    );
    fn instantiate_keys(
        ref self: TContractState,  token_quote:TokenQuoteBuyKeys,
        // registration_type: KeysMarketplace::BondingType,
    );
    fn buy_keys(
        ref self: TContractState, key_user:ContractAddress, amount:u256
    );
    fn sell_keys(
        ref self: TContractState, amount:u256
    );
    // fn get_name(self: @TContractState, address: ContractAddress) -> felt252;
    // fn get_owner(self: @TContractState) -> KeysMarketplace::Person;
}

const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");

#[starknet::contract]
mod KeysMarketplace {
    use starknet::{ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        get_block_timestamp, get_contract_address};

    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    
    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    
    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        names: LegacyMap::<ContractAddress, felt252>,
        keys_of_users: LegacyMap::<ContractAddress, Keys>,
        shares_by_users: LegacyMap::<(ContractAddress,ContractAddress), SharesKeys>,
        owner: Person,
        registration_type: LegacyMap::<ContractAddress, BondingType>,
        total_names: u128,
        initial_key_price:u256,
        protocol_fee_percent:u256,
        creator_fee:u256,
        is_fees_protocol:bool,
        is_tokens_buy_enable: LegacyMap::<ContractAddress, TokenQuoteBuyKeys>,
        default_token: TokenQuoteBuyKeys,
        is_custom_key_enable:bool,
        is_custom_token_enable:bool,

        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StoredName: StoredName,
        BuyKeys: BuyKeys,
        SellKeys: SellKeys,
        CreateKeys: CreateKeys,
        KeysUpdated:KeysUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct StoredName {
        #[key]
        user: ContractAddress,
        name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct BuyKeys {
        #[key]
        user: ContractAddress,
        name: felt252,
        supply:uint256,
        price:uint256
    }
    
    #[derive(Drop, starknet::Event)]
    struct SellKeys {
        #[key]
        user: ContractAddress,
        name: felt252,
        supply:uint256,
        price:uint256
    }

    #[derive(Drop, starknet::Event)]
    struct CreateKeys {
        #[key]
        user: ContractAddress,
        supply:uint256,
        price:uint256
    }

    #[derive(Drop, starknet::Event)]
    struct KeysUpdated {
        #[key]
        user: ContractAddress,
        supply:uint256,
        price:uint256
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct TokenQuoteBuyKeys {
        token_address: ContractAddress,
        initial_key_price:u256,
        price:uint256,
        is_enable:bool
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Keys {
    // pub struct Keys<C> {
        owner: ContractAddress,
        token_address: ContractAddress,
        price:uint256,
        total_supply:uint256,
        bonding_curve_type:BondingType,
        created_at:u64,
        token_quote:TokenQuoteBuyKeys
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct SharesKeys {
        owner: ContractAddress,
        key_address:ContractAddress,
        amount_owned:u256,
        amount_buy:u256,
        amount_sell:u256,
        created_at:u64,
    }
       
    #[derive(Drop,  starknet::Store)]
    pub enum BondingType {
        SimpleIncrease,
        Basic,
        Degens,
        finite: u256,
        // LowCap,
        // Echo: felt252,
        // Move: (u128, u128),
        infinite
    }

    trait KeysBonding {
        fn compute_current_price(self: Keys, initial_key_price:u256)-> u256;
        fn compute_current_price_by_amount(self: Keys, initial_key_price:u256, amount:u256)-> u256;
        fn calculate_new_price(self: Keys, amount_to_buy:u256)-> u256;
    }

    impl KeysBondingImpl of KeysBonding {
        fn compute_current_price(self: Keys, initial_key_price:u256) -> u256 {
            match self.bonding_curve_type {
                BondingType::Basic => { 
                    self.price
                },
                BondingType::Degens => {
                    0
                },
            }
        }
        
        fn compute_current_price_by_amount(self: Keys, initial_key_price:u256, amount:u256) -> u256 {
            match self.bonding_curve_type {
                BondingType::Basic => { 
                    let total_cost = 0;
                    total_cost
                },
                BondingType::Degens => {
                    0
                },
            }
        }
        fn calculate_new_price(self: Keys, amount_to_buy:uint256) -> u256 {
            match self.bonding_curve_type {
                BondingType::Basic => { 
                    let total_cost=0;
                    let supply=self.total_supply;
                    let current_price=self.price;
                    let token_quote=self.token_quote;
                    for (uint256 i = 0; i < amount; i++) {
                        total_cost += self.compute_current_price() + (i * token_quote.token_address);
                    }
                    total_cost
                },
                BondingType::Degens => {
                    0
                },
                // BondingType::Move((x, y)) => { 0 },
            }
        }
     
    }
 
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        init_token:TokenQuoteBuyKeys,
        initial_key_price:u256,
    // owner:Owner 
    ) {
        
        // AccessControl-related initialization
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(MINTER_ROLE, admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin);

        self.default_token.write(init_token);
        self.initial_key_price.write(initial_key_price);

    }

    // Public functions inside an impl block
    #[abi(embed_v0)]
    impl KeysMarketplace of super::IKeysMarketplace<ContractState> {

        // ADMIN

        fn set_token(ref self: ContractState, token_quote:TokenQuoteBuyKeys) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            self.is_tokens_buy_enable.write(token_quote.token_address, token_quote);
        }

        fn set_protocol_fee_percent(ref self: ContractState, protocol_fee_percent:u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.protocol_fee_percent.write(token_quote.token_address, protocol_fee_percent);
        }

        fn set_creator_fee(ref self: ContractState, creator_fee:u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.creator_fee.write(token_quote.token_address, creator_fee);
        }

        fn store_name(ref self: ContractState, name: felt252, registration_type: BondingType) {
            let caller = get_caller_address();
            self._store_name(caller, name, registration_type);
        }

        // User


        // Create keys for an user
        fn instantiate_keys(ref self: ContractState, token_quote:TokenQuoteBuyKeys,
            // registration_type: BondingType, 
        ) {
            let keys=self.keys_of_users.read(caller);
            assert!(keys.owner == ContractAddress::zero(), 'key already created');
            let initial_key_price= self.initial_key_price.read();
            
            let mut token_to_use=self.default_token.read();
            if self.is_custom_token_enable.read() {
                token_to_use=token_quote;
            }
            let key:Keys {
                owner:caller,
                token_address:caller // CREATE 404
                price:initial_key_price,
                total_supply:1,
                bonding_curve_type:BondingType::Basic,
                created_at:get_block_timestamp(),
                token_quote:token_to_use
            };

            let share_user=SharesKeys {
                owner:get_caller_address(),
                key_address:get_caller_address(),
                amount_owned:1,
                amount_buy:1,
                amount_sell:0,
                created_at:get_block_timestamp(),
            };
            self.shares_by_users.write((get_caller_address(), get_caller_address()),share_user);
            self._update_keys(caller,keys);
        }

        fn buy_keys(ref self: ContractState, buy_keys:ContractAddress, amount:u256) {
            let caller = get_caller_address();
            let old_keys=self.keys_of_users.read(buy_keys);
            assert!(keys.owner != ContractAddress::zero(), 'key not found');
            let initial_key_price= self.initial_key_price.read();

            // TODO erc20 token transfer
            let token=old_keys.token_quote;
            
            let erc20 = ERC20ABIDispatcher { contract_address: keys.token_address };
            let price = Keys::calculate_new_price(keys, amount);
            let amount_transfer=token.initial_key_price;
            let protocol_fee_percent=self.protocol_fee_percent.read();
            let amount_protocol_fee=price*protocol_fee_percent;
            // let amount_creator_fee=price*protocol_fee_percent;
            let creator_amount=price/amount_protocol_fee;
            let key:Keys {
                owner:caller,
                token_address:old_keys.token_address // CREATE 404
                created_at:old_keys.created_at,
                token_quote:old_keys.token_quote,
                price:initial_key_price,
                total_supply:old_keys.total_supply + amount,
                bonding_curve_type:old_keys.bonding_curve_type,
                
            };

            let mut old_share= self.shares_by_users.read((get_caller_address(), get_caller_address()));

            let share_user=old_share;
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
    
            self.shares_by_users.write((get_caller_address(), buy_keys),share_user);
            erc20.transfer(get_contract_address(), amount_protocol_fee);
            erc20.transfer(get_caller_address(), creator_amount);

            self._update_keys(buy_keys, keys);
        }

        fn sell_keys(ref self: ContractState, amount:u256) {
            // let caller = get_caller_address();
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
        ) {
            let total_names = self.total_names.read();
            self.names.write(user, name);
            self.registration_type.write(user, registration_type);
            self.total_names.write(total_names + 1);
            self.emit(StoredName { user: user, name: name });
        }

        fn _update_keys(
            ref self: ContractState,
            user: ContractAddress,
            keys:Keys,
            // name: felt252,
            // registration_type: BondingType
        ) {
            let total_names = self.total_names.read();
            self.names.write(user, name);
            self.registration_type.write(user, registration_type);
            self.total_names.write(total_names + 1);
            self.emit(StoredName { user: user, name: name });
        }

        // fn _update_keys(
        //     ref self: ContractState,
        //     user: ContractAddress,
        //     name: felt252,
        //     registration_type: BondingType
        // ) {
        //     let total_names = self.total_names.read();
        //     self.names.write(user, name);
        //     self.registration_type.write(user, registration_type);
        //     self.total_names.write(total_names + 1);
        //     self.emit(StoredName { user: user, name: name });
        // }
    }

    
    // Standalone public function
    // #[external(v0)]
    // fn get_contract_name(self: @ContractState) -> felt252 {
    //     'Name Registry'
    // }
    // Free function
    // fn get_owner_storage_address(self: @ContractState) -> StorageBaseAddress {
    //     self.owner.address()
    // }
  
}