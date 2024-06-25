use joy_fun::keys_types::{MINTER_ROLE, ADMIN_ROLE, OPERATOR, BURNER_ROLE, get_linear_price,};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256
    );
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);

    fn set_control_role(
        ref self: TContractState, recipient: ContractAddress, role: felt252, is_enable: bool
    );
}

pub trait ERC20HooksTrait<ContractState> {
    fn before_update(
        ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256
    );

    fn after_update(
        ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256
    );
}


#[starknet::contract]
pub mod ERC20 {
    use core::num::traits::Zero;

    use openzeppelin::access::accesscontrol::{AccessControlComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, get_caller_address, storage_access::StorageBaseAddress,
        contract_address_const, get_block_timestamp, get_contract_address,
    };
    use super::{MINTER_ROLE, ADMIN_ROLE, get_linear_price, OPERATOR, ERC20HooksTrait, Errors};
    mod Errors {
        const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
        const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
        const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
        const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
        const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
    }

    /// An empty implementation of the ERC20 hooks to be used in basic ERC20 preset contracts.
    impl ERC20HooksEmptyImpl<ContractState> of ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256
        ) {}

        fn after_update(
            ref self: ContractState, from: ContractAddress, recipient: ContractAddress, amount: u256
        ) {}
    }

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

    const MAX_STEPS_LOOP: u256 = 100;

    const MIN_FEE: u256 = 10; //0.1%
    const MAX_FEE: u256 = 1000; //10%
    const MID_FEE: u256 = 100; //1%

    const MIN_FEE_CREATOR: u256 = 100; //1%
    const MID_FEE_CREATOR: u256 = 1000; //10%
    const MAX_FEE_CREATOR: u256 = 5000; //50%

    const BPS: u256 = 10_000; // 100% = 10_000 bps


    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress,
        decimals: u8,
        admin: ContractAddress,
        minter: ContractAddress
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        assert(!recipient.is_zero(), 'ERC20: mint to the 0 address');
        self.total_supply.write(initial_supply);
        self.balances.write(recipient, initial_supply);

        // AccessControl-related initialization
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(MINTER_ROLE, admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin);
        self
            .emit(
                Event::Transfer(
                    Transfer {
                        from: contract_address_const::<0>(), to: recipient, value: initial_supply
                    }
                )
            );
    }

    #[abi(embed_v0)]
    impl IERC20Impl of super::IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self.transfer_helper(sender, recipient, amount);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let caller = get_caller_address();
            self.spend_allowance(sender, caller, amount);
            self.transfer_helper(sender, recipient, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) + added_value
                );
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) - subtracted_value
                );
        }


        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            self.transfer_helper(sender, recipient, amount);
        }

        fn set_control_role(
            ref self: ContractState, recipient: ContractAddress, role: felt252, is_enable: bool
        ) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert!(
                role == MINTER_ROLE
                    || role == ADMIN_ROLE
                    || role == OPERATOR
                    || role == BURNER_ROLE,
                "role not enable"
            );
            if is_enable {
                self.accesscontrol._grant_role(role, recipient);
            } else {
                self.accesscontrol._revoke_role(role, recipient);
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // impl InternalImpl< TContractState,

        //  impl Hooks: ERC20HooksTrait<ContractState>
        //  > of InternalTrait<TContractState> {
        fn transfer_helper(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }


        fn spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            assert(current_allowance >= amount, 'not enough allowance');
            self.allowances.write((owner, spender), current_allowance - amount);
        }

        fn approve_helper(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!spender.is_zero(), 'ERC20: approve from 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        /// Creates a `value` amount of tokens and assigns them to `account`.
        ///
        /// Requirements:
        ///
        /// - `recipient` is not the zero address.
        ///
        /// Emits a `Transfer` event with `from` set to the zero address.
        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), Errors::MINT_TO_ZERO);
            self._update(ContractAddress::zero(), recipient, amount);
        }

        /// Destroys `amount` of tokens from `account`.
        ///
        /// Requirements:
        ///
        /// - `account` is not the zero address.
        /// - `account` must have at least a balance of `amount`.
        ///
        /// Emits a `Transfer` event with `to` set to the zero address.
        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            self._update(account, ContractAddress::zero(), amount);
        }


        /// Transfers an `amount` of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is
        /// the zero address.
        ///
        /// This function can be extended using the `ERC20HooksTrait`, to add
        /// functionality before and/or after the transfer, mint, or burn.
        ///
        /// Emits a `Transfer` event.
        fn _update(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            Hooks::before_update(ref self, from, to, amount);

            // let zero_address = ContractAddress::zero();
            // let zero_address = ContractAddress::zero()
            let zero_address = ContractAddress::zero();

            if (from == zero_address) {
                let total_supply = self.total_supply.read();
                self.total_supply.write(total_supply + amount);
            } else {
                let from_balance = self.balances.read(from);
                assert(from_balance >= amount, Errors::INSUFFICIENT_BALANCE);
                self.balances.write(from, from_balance - amount);
            }

            if (to == zero_address) {
                let total_supply = self.total_supply.read();
                self.total_supply.write(total_supply - amount);
            } else {
                let to_balance = self.balances.read(to);
                self.balances.write(to, to_balance + amount);
            }

            self.emit(Transfer { from, to, value: amount });
        // Hooks::after_update(ref self, from, to, amount);
        }
    }
}

