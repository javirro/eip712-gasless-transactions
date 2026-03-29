# EIP-712 Typed Data Signing & Gasless Transactions

A practical framework demonstrating **EIP-712 typed structured data signing** across three patterns: raw signature verification, ERC-2612 token permits, and meta-transactions. Includes both on-chain (Solidity/Foundry) and off-chain (TypeScript/viem) implementations deployed on **Sepolia** and **Polygon**.

## Project Structure

```
on-chain/          # Solidity contracts (Foundry)
├── src/EIP712/    # EIP-712 base contracts + meta-transactions
├── src/ERC2612/   # ERC-20 token with permit
├── script/        # Deployment scripts
└── test/          # Foundry tests

off-chain/         # TypeScript scripts (viem + pnpm)
├── src/metaTransactions/   # Generic meta-tx signing
├── src/tokenERC2612/       # Permit & transferWithPermit signing
├── src/gasslessERC20Transfer.ts  # Two-signature gasless ERC-20 flow
└── src/smartcontract/      # ABIs & deployed addresses
```

---

## 1. EIP-712 Signature Verification (Base Layer)

Two base contracts implementing EIP-712 domain separation and signature verification. These are inherited by the meta-transaction contracts — no off-chain scripts target them directly.

| Contract | Approach | Signature Format | Key Feature |
|----------|----------|-----------------|-------------|
| `BaseEIP712.sol` | OpenZeppelin's `EIP712` + `ECDSA.recover` | Packed 65 bytes (`r ‖ s ‖ v`) | Production-ready, reusable base |
| `RawEIP7112.sol` | Manual domain separator + raw `ecrecover` | Separate `(v, r, s)` params | Malleability protection via `s ≤ HALF_CURVE_ORDER` |

Both expose `validateSignature()` (reverts on failure) and `verifySignature()` (returns bool).

**Tests:** `BaseEIP712.t.sol`, `RawEIP712.t.sol`

---

## 2. ERC-2612 Token Permits

An ERC-20 token (`TokenERC2612.sol`) implementing gasless approvals via ERC-2612, plus a custom `transferWithPermit()` for atomic single-signature transfers.

### On-chain

**`TokenERC2612.sol`** — ERC-20 with two permit flows:

- **`permit()`** — Standard ERC-2612. Owner signs a `Permit` struct; anyone can submit it to set an allowance without the owner spending gas.
- **`transferWithPermit()`** — Custom extension. Sender signs a `TransferWithPermit` struct binding the recipient; the relayer submits it and tokens move in a single transaction — no separate approve step.

Both use per-owner nonces for replay protection.

### Off-chain → On-chain Mapping

| Off-chain Script | Signs | Calls | Description |
|------------------|-------|-------|-------------|
| `permit.ts` | `Permit(owner, spender, value, nonce, deadline)` | `token.permit()` | Relayer gains allowance to spend signer's tokens |
| `transferWithPermit.ts` | `TransferWithPermit(from, to, value, nonce, deadline)` | `token.transferWithPermit()` | Atomic permit + transfer in one signature |

**Network:** Sepolia

---

## 3. Meta-Transactions

Two meta-transaction patterns enabling gasless execution. A **relayer** submits the transaction and pays gas; the **signer** only produces EIP-712 signatures.

### 3a. Generic Meta-Transactions

Execute **arbitrary contract calls** on behalf of a signer.

**On-chain:** `MetaTransactions.sol` (inherits `BaseEIP712`)
- Verifies a `MetaTx(from, target, data, nonce, deadline)` signature
- Executes a raw call to the target contract
- Demo target: `ExampleSmartContract.sol` (simple `updateValue(uint256)`)

**Off-chain:** `metaTransactions.ts`
- Encodes the target function call, signs a `MetaTx` struct, relayer calls `executeMetaTx()`

**Network:** Sepolia

### 3b. Gasless ERC-20 Transfers (Permit + Meta-Transfer)

Fully gasless ERC-20 transfers combining **two EIP-712 signatures**:

1. **ERC-2612 Permit** — signed against the token contract → authorizes the relayer to spend tokens
2. **MetaTransfer** — signed against the MetaRelayer contract → authorizes the specific transfer

**On-chain:** `MetaTransactionsWithPermit.sol` (MetaRelayer, inherits `BaseEIP712`)
- Calls `token.permit()` then `token.transferFrom()` in a single transaction
- Permit failures are silently caught (handles re-permit edge cases)

**Off-chain:** `gasslessERC20Transfer.ts`
- Signs both messages, relayer calls `executeGaslessTx(token, from, to, amount, deadline, permitSig, transferSig)`

**Network:** Polygon

---

## Deployed Contracts

| Contract | Network | Address |
|----------|---------|---------|
| MetaTransactions | Sepolia | `0xf1e76EdcFC8356EAAE03AE8937c43D8A451E0AfE` |
| ExampleSmartContract | Sepolia | `0x7E1dbe90f2109b9FBF7FD373B4dAcF51E829f312` |
| TokenERC2612 | Sepolia | `0x254301274dc1a7ED0DF68D45Ff3c39D01AA16082` |
| MetaRelayer (WithPermit) | Polygon | `0x89ab00cC30Ecf8Ac342455326B4Fb1b9E8AEfa7C` |

---

## Tech Stack

- **On-chain:** Solidity, Foundry, OpenZeppelin Contracts
- **Off-chain:** TypeScript, [viem](https://viem.sh), pnpm

## Quick Start

### On-chain

```bash
cd on-chain
forge build
forge test
```

### Off-chain

```bash
cd off-chain
pnpm install
# Configure .env with RELAYER_PRIVATE_KEY and SIGNER_PRIVATE_KEY
pnpm tsx src/metaTransactions/metaTransactions.ts
pnpm tsx src/tokenERC2612/permit.ts
pnpm tsx src/gasslessERC20Transfer.ts
```