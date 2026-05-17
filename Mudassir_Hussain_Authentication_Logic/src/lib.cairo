// Mudassir Hussain - Authentication Logic Assignment
//
// This contract demonstrates basic authentication logic in Cairo/Starknet.
// It is for learning purposes only. Do not store real passwords on a public blockchain.
// The password_hash parameter is treated as an already-hashed value.

use starknet::ContractAddress;

/// Public interface for the AuthenticationLogic contract.
#[starknet::interface]
pub trait IAuthenticationLogic<TContractState> {
    /// Register the caller with a password hash.
    fn register_user(ref self: TContractState, password_hash: felt252);

    /// Login the caller by comparing the provided hash with the stored hash.
    fn login(ref self: TContractState, password_hash: felt252) -> bool;

    /// Logout the caller.
    fn logout(ref self: TContractState);

    /// Change caller password after verifying the old hash.
    fn change_password(
        ref self: TContractState, old_password_hash: felt252, new_password_hash: felt252,
    );

    /// Admin can deactivate a user account.
    fn admin_deactivate_user(ref self: TContractState, user: ContractAddress);

    /// Admin can transfer admin control to another address.
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);

    /// Check whether a user is registered.
    fn is_registered(self: @TContractState, user: ContractAddress) -> bool;

    /// Check whether a user is currently logged in.
    fn is_authenticated(self: @TContractState, user: ContractAddress) -> bool;

    /// Get the current admin address.
    fn get_admin(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod AuthenticationLogic {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};

    /// Contract storage.
    ///
    /// admin: the account allowed to perform admin-only actions.
    /// registered_users: tells whether an address has an account.
    /// password_hashes: stores an educational password hash for each user.
    /// logged_in: tells whether a registered user is currently authenticated.
    #[storage]
    struct Storage {
        admin: ContractAddress,
        registered_users: Map<ContractAddress, bool>,
        password_hashes: Map<ContractAddress, felt252>,
        logged_in: Map<ContractAddress, bool>,
    }

    /// Constructor runs once when the contract is deployed.
    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
    }

    /// Events help external apps track important contract actions.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserRegistered: UserRegistered,
        LoginAttempt: LoginAttempt,
        UserLoggedOut: UserLoggedOut,
        PasswordChanged: PasswordChanged,
        UserDeactivated: UserDeactivated,
        AdminTransferred: AdminTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRegistered {
        #[key]
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct LoginAttempt {
        #[key]
        user: ContractAddress,
        success: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct UserLoggedOut {
        #[key]
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct PasswordChanged {
        #[key]
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct UserDeactivated {
        #[key]
        user: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminTransferred {
        #[key]
        old_admin: ContractAddress,
        #[key]
        new_admin: ContractAddress,
    }

    /// Public contract implementation.
    #[abi(embed_v0)]
    impl AuthenticationLogicImpl of super::IAuthenticationLogic<ContractState> {
        fn register_user(ref self: ContractState, password_hash: felt252) {
            let caller: ContractAddress = get_caller_address();

            // A zero hash is rejected so users do not register with an empty password value.
            assert!(password_hash != 0, "EMPTY_PASSWORD_HASH");

            // A user should not register twice.
            let already_registered: bool = self.registered_users.read(caller);
            assert!(!already_registered, "USER_ALREADY_REGISTERED");

            self.registered_users.write(caller, true);
            self.password_hashes.write(caller, password_hash);
            self.logged_in.write(caller, false);

            self.emit(UserRegistered { user: caller });
        }

        fn login(ref self: ContractState, password_hash: felt252) -> bool {
            let caller: ContractAddress = get_caller_address();

            let registered: bool = self.registered_users.read(caller);
            if (!registered) {
                self.emit(LoginAttempt { user: caller, success: false });
                return false;
            }

            let stored_hash: felt252 = self.password_hashes.read(caller);
            let success: bool = stored_hash == password_hash;

            if (success) {
                self.logged_in.write(caller, true);
            }

            self.emit(LoginAttempt { user: caller, success });
            success
        }

        fn logout(ref self: ContractState) {
            let caller: ContractAddress = get_caller_address();

            self._assert_registered(caller);
            self._assert_logged_in(caller);

            self.logged_in.write(caller, false);
            self.emit(UserLoggedOut { user: caller });
        }

        fn change_password(
            ref self: ContractState, old_password_hash: felt252, new_password_hash: felt252,
        ) {
            let caller: ContractAddress = get_caller_address();

            self._assert_registered(caller);
            assert!(new_password_hash != 0, "EMPTY_NEW_PASSWORD");

            let stored_hash: felt252 = self.password_hashes.read(caller);
            assert!(stored_hash == old_password_hash, "WRONG_OLD_PASSWORD");

            self.password_hashes.write(caller, new_password_hash);

            // User must login again after changing password.
            self.logged_in.write(caller, false);

            self.emit(PasswordChanged { user: caller });
        }

        fn admin_deactivate_user(ref self: ContractState, user: ContractAddress) {
            self._assert_admin();

            self.registered_users.write(user, false);
            self.password_hashes.write(user, 0);
            self.logged_in.write(user, false);

            self.emit(UserDeactivated { user });
        }

        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            self._assert_admin();

            let old_admin: ContractAddress = self.admin.read();
            assert!(old_admin != new_admin, "SAME_ADMIN");

            self.admin.write(new_admin);
            self.emit(AdminTransferred { old_admin, new_admin });
        }

        fn is_registered(self: @ContractState, user: ContractAddress) -> bool {
            self.registered_users.read(user)
        }

        fn is_authenticated(self: @ContractState, user: ContractAddress) -> bool {
            let registered: bool = self.registered_users.read(user);
            let active_session: bool = self.logged_in.read(user);

            registered && active_session
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }
    }

    /// Internal helper functions. These are not exposed in the contract ABI.
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assert_admin(self: @ContractState) {
            let caller: ContractAddress = get_caller_address();
            let admin: ContractAddress = self.admin.read();
            assert!(caller == admin, "ONLY_ADMIN");
        }

        fn _assert_registered(self: @ContractState, user: ContractAddress) {
            let registered: bool = self.registered_users.read(user);
            assert!(registered, "USER_NOT_REGISTERED");
        }

        fn _assert_logged_in(self: @ContractState, user: ContractAddress) {
            let active_session: bool = self.logged_in.read(user);
            assert!(active_session, "USER_NOT_LOGGED_IN");
        }
    }
}
