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
    pub caller: ContractAddress,
    #[key]
    pub key_user: ContractAddress,
    pub amount: u256,
    pub price: u256,
    pub protocol_fee: u256,
    pub creator_fee: u256
}

#[derive(Drop, starknet::Event)]
pub struct SellKeys {
    #[key]
    pub caller: ContractAddress,
    #[key]
    pub key_user: ContractAddress,
    pub amount: u256,
    pub price: u256,
    pub protocol_fee: u256,
    pub creator_fee: u256
}

#[derive(Drop, starknet::Event)]
pub struct CreateKeys {
    #[key]
    pub caller: ContractAddress,
    #[key]
    pub key_user: ContractAddress,
    pub amount: u256,
    pub price: u256,
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
    pub initial_key_price:u256,
    pub total_supply: u256,
    // pub bonding_curve_type: BondingType,
    pub created_at: u64,
    pub token_quote: TokenQuoteBuyKeys
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct SharesKeys {
    pub owner: ContractAddress,
    pub key_address: ContractAddress,
    pub amount_owned: u256,
    pub amount_buy: u256,
    pub amount_sell: u256,
    pub created_at: u64,
    pub total_paid:u256,
}

#[derive(Drop, Serde, Clone, starknet::Store)]
pub enum BondingType {
    Basic,
    SimpleIncrease,
    Degens,
}

pub trait KeysBonding {
    // fn compute_current_price(self: Keys, initial_key_price: u256) -> u256;
    // fn compute_current_price_by_amount(self: Keys, initial_key_price: u256, amount: u256) -> u256;
    // fn calculate_new_price(self: Keys, amount_to_buy: u256) -> u256;
    // fn get_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256;
    // fn get_current_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256;
}

pub impl KeysBondingImpl of KeysBonding {
    // fn compute_current_price(self: Keys, initial_key_price: u256) -> u256 {
    //     match self.bonding_curve_type {
    //         BondingType::SimpleIncrease => { self.price },
    //         BondingType::Basic => { 0 },
    //         BondingType::Degens => { 0 },
    //     }
    // }

    // fn compute_current_price_by_amount(self: Keys, initial_key_price: u256, amount: u256) -> u256 {
    //     match self.bonding_curve_type {
    //         BondingType::SimpleIncrease => { 0 },
    //         BondingType::Basic => {
    //             let total_cost = 0;
    //             total_cost
    //         },
    //         BondingType::Degens => { 0 },
    //     }
    // }
    // fn calculate_new_price(self: Keys, amount_to_buy: u256) -> u256 {
    //     match self.bonding_curve_type {
    //         BondingType::Basic => {
    //             let total_cost = 0;
    //             let supply = self.total_supply;
    //             let current_price = self.price;
    //             let token_quote = self.token_quote;
    //             // for (u256 i = 0; i < amount; i++) {
    //             //     total_cost += self.compute_current_price() + (i * token_quote.token_address);
    //             // }
    //             total_cost
    //         },
    //         BondingType::Degens => { 0 },
    //         BondingType::SimpleIncrease => { 0 }
    //     }
    // }
    // fn get_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256 {
    //     match self.bonding_curve_type {
    //         BondingType::Basic => {
    //             let total_cost = 0;
    //             let current_price = self.price;
    //             let token_quote = self.token_quote;

    //             total_cost
    //         },
    //         BondingType::Degens => { 0 },
    //         BondingType::SimpleIncrease => { 0 }
    //     }
    // }
    // //   fn get_current_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256 {
    //   fn get_current_price(self: Keys, supply: u256, amount_to_buy: u256) -> u256 {
    //     match self.bonding_curve_type {
    //         BondingType::Basic => {
    //             let total_cost = 0;
    //             let current_price = self.price;
    //             let token_quote = self.token_quote;

    //             total_cost

    //         //        let total_cost = 0;
    //         //     let current_price = self.price;
    //         //     let token_quote = self.token_quote;

    //         //     // total_cost
    //         //       let token = self.token_quote.clone();
    //         // let token_address = self.token_address;
    //         // let bonding_curve_type = self.bonding_curve_type;
    //         // let total_supply = self.total_supply;



    //         // let mut actual_supply=total_supply;
    //         // let final_supply=total_supply+amount;
    //         // let mut step=final_supply-amount;
    //         // let current_price = self.price.clone();
    //         // let mut price = current_price;
    //         // let mut total_price = price;


    //         // let result = loop {
    //         //     let price_for_this_key = (actual_supply)/16_000* token_quote.initial_key_price;
    //         //     price+=price_for_this_key;
    //         //     total_price+=price_for_this_key;
    //         //     if final_supply == actual_supply {
    //         //         break actual_supply;
    //         //     }
    //         //     actual_supply += 1;
    //         // };

    //         // total_price
    //         },
    //         BondingType::Degens => { 0 },
    //         BondingType::SimpleIncrease => { 0 }
    //     }
    // }
}


pub fn get_current_price(key: @Keys, supply: u256, amount_to_buy: u256) -> u256 {
                let total_cost = 0;
                let current_price = key.price;
                let token_quote = key.token_quote;

                total_cost
        // match key.bonding_curve_type {
        //     BondingType::Basic => {
        //         let total_cost = 0;
        //         let current_price = key.price;
        //         let token_quote = key.token_quote;

        //         total_cost
        //     },
        //     BondingType::Degens => { 0 },
        //     BondingType::SimpleIncrease => { 0 }
        // }
}
