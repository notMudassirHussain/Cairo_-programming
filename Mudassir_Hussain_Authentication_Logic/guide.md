# Authentication Logic in Cairo

## Student

Mudassir Hussain

## Topic

Authentication Logic

## Assignment Overview

This assignment implements a simple authentication logic smart contract using Cairo and Starknet. The purpose of the contract is to demonstrate how a smart contract can identify the caller, register users, verify login attempts, manage login status, allow password changes, and restrict admin-only actions.

The implementation is educational. In real blockchain applications, developers should not store real passwords or raw password hashes directly on-chain because public blockchain data can be viewed by anyone. This contract uses a `password_hash` value only to demonstrate authentication logic.

## Main Concepts Covered

### 1. Contract Address

Starknet accounts and contracts are represented by `ContractAddress`. In this assignment, each user is identified by their caller address. The contract gets the caller address using `get_caller_address()`.

### 2. Storage Variables

The contract stores persistent state inside the `Storage` struct:

- `admin`: stores the admin address.
- `registered_users`: stores whether an address is registered.
- `password_hashes`: stores the password hash value for each registered user.
- `logged_in`: stores whether a user currently has an active session.

The contract uses `Map<ContractAddress, bool>` and `Map<ContractAddress, felt252>` to map user addresses to values.

### 3. Constructor

The constructor runs once during deployment. It receives an `admin` address and stores it as the contract admin. The admin can deactivate users and transfer admin control.

### 4. Registration

The `register_user` function allows the caller to create an account. It checks that:

- the password hash is not zero;
- the caller is not already registered.

After registration, the user is marked as registered, the password hash is saved, and the login state is set to false.

### 5. Login

The `login` function compares the password hash provided by the caller with the stored password hash. If the hash matches, the contract marks the caller as logged in and returns `true`. If the user is not registered or the hash does not match, it returns `false`.

### 6. Logout

The `logout` function allows a logged-in user to end their session. It checks that the caller is registered and currently logged in before changing the login status to false.

### 7. Password Change

The `change_password` function lets a registered user update their password hash. The user must provide the correct old password hash. After the password is changed, the user is logged out and must login again with the new hash.

### 8. Admin Controls

The contract includes admin-only functions:

- `admin_deactivate_user`: disables a user account and clears their stored password hash.
- `transfer_admin`: transfers admin control to another address.

These functions use the internal `_assert_admin` helper to ensure that only the admin can call them.

### 9. Events

The contract emits events for important actions:

- `UserRegistered`
- `LoginAttempt`
- `UserLoggedOut`
- `PasswordChanged`
- `UserDeactivated`
- `AdminTransferred`

Events help front-end applications and blockchain indexers track what happened in the contract.

## Function Summary

| Function | Purpose |
|---|---|
| `register_user(password_hash)` | Registers the caller as a user |
| `login(password_hash)` | Authenticates the caller |
| `logout()` | Logs out the caller |
| `change_password(old_password_hash, new_password_hash)` | Changes the caller password hash |
| `admin_deactivate_user(user)` | Admin disables a user |
| `transfer_admin(new_admin)` | Admin transfers admin rights |
| `is_registered(user)` | Checks if a user is registered |
| `is_authenticated(user)` | Checks if a user is registered and logged in |
| `get_admin()` | Returns the current admin address |

## Security Notes

This contract is for learning only. A production authentication system should not store passwords or simple password hashes on-chain. Since blockchain storage is public, sensitive authentication secrets should be handled off-chain or through cryptographic proof systems. This assignment focuses on learning Cairo concepts such as storage, mappings, caller address, assertions, events, and access control.

## How to Build

From this folder, run:

```bash
scarb build
```

If the build succeeds, Scarb will create the compiled Starknet contract artifact inside the `target/dev` directory.

## Files

```text
Authentication_Logic/
├── Scarb.toml
├── guide.md
└── src
    └── lib.cairo
```

## What I Learned

Through this assignment, I learned how to:

- define a Starknet smart contract in Cairo;
- use `ContractAddress` and `get_caller_address()`;
- store and read persistent values from contract storage;
- use mappings for user-based data;
- write public and internal contract functions;
- protect admin-only functionality;
- emit events for important actions;
- structure a Cairo project so it can build with Scarb.
