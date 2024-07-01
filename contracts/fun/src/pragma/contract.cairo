use starknet::ContractAddress;

const KEY: felt252 =
    18669995996566340; // felt252 conversion of "BTC/USD", can also write const KEY : felt252 = 'BTC/USD';

#[starknet::interface]
trait OraclePragmaABI<TContractState> {
    fn initializer(
        ref self: TContractState,
        pragma_contract: ContractAddress, // summary_stats: ContractAddress
    );
    fn check_eth_threshold(self: @TContractState, threshold: u32) -> bool;
    fn get_asset_price(self: @TContractState, asset_id: felt252) -> u128;
    fn realized_volatility(self: @TContractState) -> (u128, u32);
}


#[starknet::contract]
mod OraclePragma {
    use alexandria_math::pow;
    use array::{ArrayTrait, SpanTrait};
    use option::OptionTrait;
    use pragma_lib::abi::{
        IPragmaABIDispatcher, IPragmaABIDispatcherTrait, ISummaryStatsABIDispatcher,
        ISummaryStatsABIDispatcherTrait
    };

    use pragma_lib::types::{DataType, AggregationMode, PragmaPricesResponse};
    use starknet::get_block_timestamp;
    use super::{ContractAddress, OraclePragmaABI};
    use traits::{Into, TryInto};

    const ETH_USD: felt252 = 'ETH/USD';
    const BTC_USD: felt252 = 'BTC/USD';

    #[storage]
    struct Storage {
        pragma_contract: ContractAddress,
        summary_stats: ContractAddress,
        assets_felts: LegacyMap::<ContractAddress, felt252>,
        tokens_enable: LegacyMap::<ContractAddress, bool>,
        assets_ids: List<felt252>,
    }

    #[abi(embed_v0)]
    impl OraclePragmaABIImpl of OraclePragmaABI<ContractState> {
        fn initializer(
            ref self: ContractState,
            pragma_contract: ContractAddress, // summary_stats: ContractAddress
        ) {
            if self.pragma_contract.read().into() == 0 {
                self.pragma_contract.write(pragma_contract);
            }
        // if self.summary_stats.read().into() == 0 {
        //     self.summary_stats.write(summary_stats);
        // }
        }


        fn set_creator_fee_percent(ref self: ContractState, creator_fee_percent: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            assert(creator_fee_percent < MAX_FEE_CREATOR, 'creator_fee_too_high');
            assert(creator_fee_percent > MIN_FEE_CREATOR, 'creator_fee_too_low');

            self.creator_fee_percent.write(creator_fee_percent);
        }

        fn check_eth_threshold(self: @ContractState, threshold: u32) -> bool {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read()
            };

            // Call the Oracle contract
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_median(DataType::SpotEntry(ETH_USD));

            // We only care about DEFILLAMA and COINBASE
            let defillama: felt252 = 'DEFILLAMA';
            let coinbase: felt252 = 'COINBASE';

            let mut sources = array![defillama, coinbase];
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_for_sources(
                    DataType::SpotEntry(BTC_USD), AggregationMode::Median(()), sources.span()
                );

            // Normalize based on number of decimals
            let decimals: u128 = output.decimals.into();
            let multiplier: u128 = pow(10, decimals);

            // Shift the threshold by the multiplier
            let shifted_threshold: u128 = threshold.into() * multiplier;

            return shifted_threshold <= output.price;
        }
        fn get_asset_price(self: @ContractState, asset_id: felt252) -> u128 {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read()
            };

            // Call the Oracle contract, for a spot entry
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_median(DataType::SpotEntry(asset_id));

            return output.price;
        }

        fn realized_volatility(self: @ContractState) -> (u128, u32) {
            let oracle_dispatcher = ISummaryStatsABIDispatcher {
                contract_address: self.summary_stats.read()
            };

            let key = 'ETH/USD';
            let timestamp = starknet::get_block_timestamp();

            let start = timestamp - 259200000; // 1 month ago
            let end = timestamp; // now

            let num_samples = 200; // Maximum 200 because of Cairo Steps limit

            let (volatility, decimals) = oracle_dispatcher
                .calculate_volatility(
                    DataType::SpotEntry(key),
                    start.into(),
                    end.into(),
                    num_samples,
                    AggregationMode::Median(())
                );

            let (mean, mean_decimals) = oracle_dispatcher
                .calculate_mean(
                    DataType::SpotEntry(key), start.into(), end.into(), AggregationMode::Median(())
                );

            (volatility, decimals)
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _get_asset_price_median(oracle_address: ContractAddress, asset: DataType) -> u128 {
            let oracle_dispatcher = IPragmaABIDispatcher { contract_address: oracle_address };
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data(asset, AggregationMode::Median(()));
            return output.price;
        }


        fn _get_asset_price_average(
            oracle_address: ContractAddress, asset: DataType, sources: Span<felt252>
        ) -> u128 {
            let oracle_dispatcher = IPragmaABIDispatcher { contract_address: oracle_address };
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_for_sources(asset, AggregationMode::Mean(()), sources);

            return output.price;
        }

        fn _get_price() { // //USAGE
        // let oracle_address : ContractAddress = contract_address_const::<0x06df335982dddce41008e4c03f2546fa27276567b5274c7d0c1262f3c2b5d167>();
        // let price = get_asset_price_median(oracle_address, DataType::SpotEntry(KEY));
        }
    }
}
