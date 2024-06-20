use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct StoredName {
    #[key]
    user: ContractAddress,
    name: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Person {
    address: ContractAddress,
    name: felt252,
}

