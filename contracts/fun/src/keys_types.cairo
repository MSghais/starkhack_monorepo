use starknet::{
    ContractAddress, get_caller_address, storage_access::StorageBaseAddress, contract_address_const,
    get_block_timestamp, get_contract_address,
};

pub const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
pub const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
pub const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");

#[derive(Drop, starknet::Event)]
pub struct StoredName {
    #[key]
    pub user: ContractAddress,
    pub name: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct BuyKeys {
    #[key]
    pub user: ContractAddress,
    pub name: felt252,
    pub supply: u256,
    price: u256
}

#[derive(Drop, starknet::Event)]
pub struct SellKeys {
    #[key]
    user: ContractAddress,
    name: felt252,
    supply: u256,
    price: u256
}

#[derive(Drop, starknet::Event)]
pub struct CreateKeys {
    #[key]
    user: ContractAddress,
    supply: u256,
    price: u256
}

#[derive(Drop, starknet::Event)]
pub struct KeysUpdated {
    #[key]
    user: ContractAddress,
    supply: u256,
    price: u256
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct TokenQuoteBuyKeys {
    pub token_address: ContractAddress,
    pub initial_key_price: u256,
    pub price: u256,
    pub is_enable: bool
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct Keys {
    // pub struct Keys<C> {
    pub owner: ContractAddress,
    pub token_address: ContractAddress,
    pub price: u256,
    pub total_supply: u256,
    pub bonding_curve_type: BondingType,
    pub created_at: u64,
    pub token_quote: TokenQuoteBuyKeys
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SharesKeys {
    pub owner: ContractAddress,
    pub key_address: ContractAddress,
    pub amount_owned: u256,
    pub amount_buy: u256,
    pub amount_sell: u256,
    pub created_at: u64,
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub enum BondingType {
    SimpleIncrease,
    Basic,
    Degens,
}

pub trait KeysBonding {
    fn compute_current_price(self: Keys, initial_key_price: u256) -> u256;
    fn compute_current_price_by_amount(self: Keys, initial_key_price: u256, amount: u256) -> u256;
    fn calculate_new_price(self: Keys, amount_to_buy: u256) -> u256;
    fn get_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256;
}

pub impl KeysBondingImpl of KeysBonding {
    fn compute_current_price(self: Keys, initial_key_price: u256) -> u256 {
        match self.bonding_curve_type {
            BondingType::SimpleIncrease => { self.price },
            BondingType::Basic => { 0 },
            BondingType::Degens => { 0 },
        }
    }

    fn compute_current_price_by_amount(self: Keys, initial_key_price: u256, amount: u256) -> u256 {
        match self.bonding_curve_type {
            BondingType::SimpleIncrease => { 0 },
            BondingType::Basic => {
                let total_cost = 0;
                total_cost
            },
            BondingType::Degens => { 0 },
        }
    }
    fn calculate_new_price(self: Keys, amount_to_buy: u256) -> u256 {
        match self.bonding_curve_type {
            BondingType::Basic => {
                let total_cost = 0;
                let supply = self.total_supply;
                let current_price = self.price;
                let token_quote = self.token_quote;
                // for (u256 i = 0; i < amount; i++) {
                //     total_cost += self.compute_current_price() + (i * token_quote.token_address);
                // }
                total_cost
            },
            BondingType::Degens => { 0 },
            BondingType::SimpleIncrease => { 0 }
        }
    }
    fn get_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256 {
        match self.bonding_curve_type {
            BondingType::Basic => {
                let total_cost = 0;
                let current_price = self.price;
                let token_quote = self.token_quote;

                total_cost
            },
            BondingType::Degens => { 0 },
            BondingType::SimpleIncrease => { 0 }
        }
    }
}
