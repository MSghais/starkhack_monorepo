use starknet::{
    ContractAddress, get_caller_address, storage_access::StorageBaseAddress, contract_address_const,
    get_block_timestamp, get_contract_address,
};
pub const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
pub const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
pub const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");
pub const OPERATOR: felt252 = selector!("OPERATOR");

// Storage

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Deposit {
    pub owner: ContractAddress,
    pub buy_token_address: ContractAddress,
    pub price: u256,
    pub initial_key_price: u256,
    pub amount: u256,
    pub total_supply: u256,
    pub created_at: u64,
    pub token_quote: ContractAddress
}


#[derive(Serde, Copy, // Clone,
 Drop, starknet::Store, //  PartialEq
)]
pub enum BondingType {
    Linear,
    Scoring, // Nostr data with Appchain connected to a Relayer
    Exponential,
    Limited
}

// Event

#[derive(Drop, starknet::Event)]
pub struct DepositToken {
    #[key]
    pub caller: ContractAddress,
    #[key]
    pub key_user: ContractAddress,
    #[key]
    pub token_quote: ContractAddress,
    #[key]
    pub asset_buy: ContractAddress,
    pub amount: u256,
    pub price: u256,
    pub protocol_fee: u256,
    pub creator_fee: u256
}

#[derive(Drop, starknet::Event)]
pub struct WithdrawToken {
    #[key]
    pub caller: ContractAddress,
    #[key]
    pub key_user: ContractAddress,
    #[key]
    pub token_quote: ContractAddress,
    #[key]
    pub asset_buy: ContractAddress,
    pub amount: u256,
    pub price: u256,
    pub protocol_fee: u256,
    pub creator_fee: u256
}


#[derive(Drop, starknet::Event)]
pub struct StakeToken {
    #[key]
    pub caller: ContractAddress,
    #[key]
    pub key_user: ContractAddress,
    #[key]
    pub token_quote: ContractAddress,
    #[key]
    pub asset_buy: ContractAddress,
    pub amount: u256,
    pub price: u256,
    pub protocol_fee: u256,
    pub creator_fee: u256
}

