# Gasless ERC20 Transfer — Off-chain Script

Allows a user to transfer ERC20 tokens without paying gas. The user signs two EIP-712 messages; a relayer submits the transaction.

---

## Signature 1 — ERC-2612 Permit

Authorizes the `MetaRelayer` contract to spend tokens on behalf of the user.

**Domain** — signed against the **token contract**:
```
name, version    → read from the token contract
chainId          → current network
verifyingContract → token address (e.g. USDC)
```

**Typed data:**
```
Permit(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
```
| Field      | Value                          |
|------------|--------------------------------|
| `owner`    | signer's address               |
| `spender`  | MetaRelayer contract address   |
| `value`    | token amount in wei            |
| `nonce`    | `token.nonces(owner)`          |
| `deadline` | `now + 3600`                   |

---

## Signature 2 — Meta-Transfer (EIP-712)

Authorizes the relayer to execute the actual transfer on behalf of the user.

**Domain** — signed against the **MetaRelayer contract**:
```
name, version    → read from MetaRelayer via getNameAndVersion()
chainId          → current network
verifyingContract → MetaRelayer address
```

**Typed data:**
```
MetaTransfer(address token, address from, address to, uint256 amount, uint256 nonce, uint256 deadline)
```
| Field      | Value                          |
|------------|--------------------------------|
| `token`    | token address                  |
| `from`     | signer's address               |
| `to`       | recipient address              |
| `amount`   | token amount in wei            |
| `nonce`    | `MetaRelayer.nonces(from)`     |
| `deadline` | same as permit deadline        |

---

## Execution flow

```
Signer  --[permitSig + transferSig]--> Relayer
Relayer --[executeGaslessTx()      ]--> MetaRelayer
MetaRelayer  --> token.permit()   (sets allowance)
MetaRelayer  --> token.transferFrom(from, to, amount)
```

Both signatures share the same `deadline`. The relayer pays gas; the signer pays nothing.
