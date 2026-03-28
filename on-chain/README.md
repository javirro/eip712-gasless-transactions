# Gasless Meta-Transactions — On-chain Contracts

Solidity 0.8.33 · Foundry · OpenZeppelin

---

## Contracts

### `BaseEIP712` (`src/EIP712/BaseEIP712.sol`)
Abstract base extending OZ's `EIP712`. Provides:
- `validateSignature(signer, structHash, sig)` — reverts if signature is invalid
- `verifySignature(signer, structHash, sig)` — returns bool
- `SIGNATURE_LENGTH = 65` constant used across all signature checks

### `MetaTransactions` (`src/EIP712/MetaTransactions.sol`)
Main contract. Inherits `BaseEIP712`. Enables gasless calls to any smart contract: the user signs a `MetaTx` struct off-chain and a relayer submits it on-chain.

**Key state:**
```solidity
mapping(address => uint256) public nonces;
```

**Entry point:**
```solidity
function executeMetaTx(
    address from,      // signer (the user)
    address target,    // contract to call
    bytes calldata data,     // calldata for the target
    uint256 deadline,
    bytes calldata sig // EIP-712 MetaTx signature
) external
```

**Execution steps:**
1. Validates `deadline` and `sig` length (must be 65 bytes)
2. Recovers signer from `sig` against the `MetaTx` struct hash — reverts with `MetaTransactions__InvalidSignature` if mismatch
3. Increments `nonces[from]`
4. Calls `target.call(data)` — reverts with `MetaTransactions__CallFailed` if the call fails

**MetaTx typehash:**
```
MetaTx(address from, address target, bytes data, uint256 nonce, uint256 deadline)
```

> `bytes data` is encoded as `keccak256(data)` inside the struct hash, as required by EIP-712 for dynamic types.

---

## Deploy

```bash
forge script script/DeployMetaTransactions.s.sol --fork-url polygon --broadcast
```

Requires `PRIVATE_KEY` in environment. Deploys with `name = "MetaRelayer"`, `version = "1"`.

---

## Test

```bash
forge test
```
