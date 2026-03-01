// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {BaseEIP712} from "./BaseEIP712.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 * @dev Extended interface for ERC20Permit to include a permit function with a signature parameter.
 * @notice Openzeppelin's IERC20Permit interface defines the permit function with separate parameters for the signature components (v, r, s).
 * This extended interface allows for a single bytes parameter to be used for the signature, which can be more convenient for certain use cases.
 */
interface IERC20PermitExtended is IERC20Permit {
  function permit( address owner, address spender, uint256 value, uint256 deadline, bytes memory signature ) external;
}


/**
 * @title MetaRelayer
 * @dev A contract that enables gasless ERC20 transfers using EIP-712 signatures.
 *      Users can authorize token transfers by signing a meta-transfer struct and an ERC-2612 permit,
 *      allowing relayers to execute the transfer on their behalf without requiring them to hold tokens or pay gas.
 */
contract MetaRelayer is BaseEIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant META_TRANSFER_TYPEHASH = keccak256(
        "MetaTransfer(address token,address from,address to,uint256 amount,uint256 nonce,uint256 deadline)"
    );

    struct MetaTransfer {
        address token;
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => uint256) public nonces;

    error MetaRelayer__InvalidSignature();
    error MetaRelayer__InvalidSigner();
    error MetaRelayer__ExpiredDeadline();
    error MetaRelayer__InvalidPermitSignature();

    event MetaTransferExecuted(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    constructor(string memory name, string memory version) BaseEIP712(name, version) {}


      /**
      * @notice Executes a gasless ERC20 transfer authorized by the user via EIP-712 signatures. The user must sign both a permit (ERC-2612) and a meta-transfer struct. The relayer submits both signatures in a single transaction.
       * @param token         The address of the ERC20 token to transfer
       * @param from          The address of the token sender (the user)
       * @param to            The address of the token recipient
       * @param amount        The amount of tokens to transfer
       * @param deadline      The timestamp after which the meta-transfer is no longer valid
       * @param permitSig     The 65-byte signature for the ERC-2612 permit
       * @param transferSig   The 65-byte EIP-712 signature for the meta-transfer authorization
       */
    function executeGaslessTx (address token, address from, address to, uint256 amount, uint256 deadline, bytes memory permitSig, bytes memory transferSig) external {
      if (block.timestamp > deadline) revert MetaRelayer__ExpiredDeadline();
      if (from == address(0)) revert MetaRelayer__InvalidSigner();
      if (permitSig.length != SIGNATURE_LENGTH) revert MetaRelayer__InvalidPermitSignature();
      if (transferSig.length != SIGNATURE_LENGTH) revert MetaRelayer__InvalidSignature();
      MetaTransfer memory metaTx = MetaTransfer({
            token: token,
            from: from,
            to: to,
            amount: amount,
            nonce: nonces[from],
            deadline: deadline
        });
        _executeGaslessTransfer(metaTx, permitSig, transferSig);
    }


    /**
     * @notice Internal function to execute gassless ERC20Transfer.
     * @param metaTx       Struct containing token, from, to, amount, nonce, and deadline
     * @param permitSig     65-byte signature authorizing this contract to spend `amount`
     * @param transferSig   65-byte EIP-712 signature authorizing the meta-transfer
     */
    function _executeGaslessTransfer(MetaTransfer memory metaTx, bytes memory permitSig,  bytes memory transferSig) internal {

        // Step 1: Submit permit — sets allowance on the token contract
        // If permit fails (wrong sig, expired, already set) we catch and continue
        // because the user may have already approved in a previous call
        _tryPermit(metaTx.token, metaTx.from, metaTx.amount, metaTx.deadline, permitSig);

        // Step 2: Verify meta-transfer signature
        bytes32 structHash = _createStructHash(metaTx);
        validateSignature(metaTx.from, structHash, transferSig);
        nonces[metaTx.from]++;

        // Step 3: Execute transfer
        IERC20(metaTx.token).safeTransferFrom(metaTx.from, metaTx.to, metaTx.amount);

        emit MetaTransferExecuted(metaTx.token, metaTx.from, metaTx.to, metaTx.amount);
    }

    /** @dev Creates the struct hash for the given MetaTransfer, which is used in EIP-712 signature verification.
     * @param metaTx The MetaTransfer struct containing the details of the transfer.
     * @return The keccak256 hash of the encoded MetaTransfer struct, which is used as the message hash for signature verification.
     */
    function _createStructHash(MetaTransfer memory metaTx) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                META_TRANSFER_TYPEHASH,
                metaTx.token,
                metaTx.from,
                metaTx.to,
                metaTx.amount,
                metaTx.nonce,
                metaTx.deadline
            )
        );
    }

     /**
     * @dev Attempts to call permit. Silently ignores failures because:
     *      - The allowance may already be set from a previous call
     *      - Some tokens revert on re-permit with the same nonce
     *      The actual allowance check is enforced implicitly by safeTransferFrom.
     */
    function _tryPermit(address token, address from, uint256 amount, uint256 deadline, bytes memory permitSig) internal{
        try IERC20PermitExtended(token).permit(from, address(this), amount, deadline, permitSig) {}
        catch {}
    }
}