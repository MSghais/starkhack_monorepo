use joy_fun::types::defi_types::{MINTER_ROLE, ADMIN_ROLE, OPERATOR, BURNER_ROLE};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IJBTC<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn set_control_role(
        ref self: TContractState, recipient: ContractAddress, role: felt252, is_enable: bool
    );
}

#[starknet::contract]
mod JBTC {
    use openzeppelin::access::accesscontrol::{AccessControlComponent};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::IERC20Metadata;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use super::{MINTER_ROLE, ADMIN_ROLE, OPERATOR, BURNER_ROLE};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    // #[abi(embed_v0)]
    // impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

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
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_supply: u256,
        recipient: ContractAddress,
        admin: ContractAddress
    ) {
        let name = "joyBTC";
        let symbol = "jBTC";

        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);

        // AccessControl-related initialization
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(MINTER_ROLE, admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, admin);
    }

    // #[abi(embed_v0)]
    // impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
    //     // impl ERC20MetadataImpl of interface::IERC20Metadata<ContractState> {
    //     fn name(self: @ContractState) -> ByteArray {
    //         self.erc20.name()
    //     }

    //     fn symbol(self: @ContractState) -> ByteArray {
    //         self.erc20.symbol()
    //     }

    //     fn decimals(self: @ContractState) -> u8 {
    //         self.decimals.read()
    //     }
    // }

    // Public functions inside an impl block
    #[abi(embed_v0)]
    impl JBTC of super::IJBTC<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.erc20.mint(recipient, amount);
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
    impl InternalImpl of InternalTrait { // fn _set_decimals(ref self: ContractState, decimals: u8) {
    //     self.decimals.write(decimals);
    // }
    }
}
