# Gasless ERC20 Transfer — On-chain Contracts

Solidity 0.8.33 · Foundry · OpenZeppelin

---

## Contracts

### `BaseEIP712` (`src/EIP712/BaseEIP712.sol`)
Abstract base extending OZ's `EIP712`. Provides:
- `validateSignature(signer, structHash, sig)` — reverts if signature is invalid
- `verifySignature(signer, structHash, sig)` — returns bool
- `SIGNATURE_LENGTH = 65` constant used across all signature checks

### `MetaRelayer` (`src/EIP712/MetaTransactions.sol`)
Main contract. Inherits `BaseEIP712`.

**Key state:**
```solidity
mapping(address => uint256) public nonces;
```

**Entry point:**
```solidity
function executeGaslessTx(
    address token,
    address from,
    address to,
    uint256 amount,
    uint256 deadline,
    bytes memory permitSig,    // ERC-2612 permit signature
    bytes memory transferSig   // EIP-712 MetaTransfer signature
) external
```

**Execution steps:**
1. Validates `deadline` and signature lengths
2. Calls `token.permit(from, address(this), amount, deadline, permitSig)` — silently ignores revert (allowance may already be set)
3. Recovers signer from `transferSig` against the `MetaTransfer` struct hash — reverts if mismatch
4. Increments `nonces[from]`
5. Calls `token.safeTransferFrom(from, to, amount)`

**MetaTransfer typehash:**
```
MetaTransfer(address token, address from, address to, uint256 amount, uint256 nonce, uint256 deadline)
```

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
