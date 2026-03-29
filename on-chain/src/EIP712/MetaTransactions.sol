// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {BaseEIP712} from "./BaseEIP712.sol";

/**
 * @title MetaTransactions
 * @dev A contract that enables gasless calls to other smart contracts using EIP-712 signatures.
 *      Users authorize a contract call by signing a meta-transaction struct,
 *      allowing relayers to execute the call on their behalf without requiring them to pay gas.
 */
contract MetaTransactions is BaseEIP712 {

    bytes32 public constant META_TX_TYPEHASH = keccak256(
        "MetaTx(address from,address target,bytes data,uint256 nonce,uint256 deadline)"
    );

    struct MetaTx {
        address from;
        address target;
        bytes data;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => uint256) public nonces;

    error MetaTransactions__InvalidSignature();
    error MetaTransactions__InvalidSigner();
    error MetaTransactions__ExpiredDeadline();
    error MetaTransactions__CallFailed();

    event MetaTxExecuted(address indexed from, address indexed target);

    constructor(string memory name, string memory version) BaseEIP712(name, version) {}

    /**
     * @notice Executes a gasless call to a target contract authorized by the user via an EIP-712 signature.
     * @param from      The address of the signer (the user)
     * @param target    The address of the contract to call
     * @param data      The calldata to send to the target contract
     * @param deadline  The timestamp after which the meta-transaction is no longer valid
     * @param sig       The 65-byte EIP-712 signature authorizing the meta-transaction
     */
    function executeMetaTx(address from, address target, bytes calldata data, uint256 deadline, bytes calldata sig) external {
        if (block.timestamp > deadline) revert MetaTransactions__ExpiredDeadline();
        if (from == address(0)) revert MetaTransactions__InvalidSigner();
        if (sig.length != SIGNATURE_LENGTH) revert MetaTransactions__InvalidSignature();

        MetaTx memory metaTx = MetaTx({
            from: from,
            target: target,
            data: data,
            nonce: nonces[from],
            deadline: deadline
        });

        bytes32 structHash = _createStructHash(metaTx);
        validateSignature(from, structHash, sig);
        nonces[from]++;

        // Perform the call to the target contract with the provided data
        (bool success,) = target.call(data);
        if (!success) revert MetaTransactions__CallFailed();

        emit MetaTxExecuted(from, target);
    }

    /**
     * @dev Creates the struct hash for the given MetaTx, used in EIP-712 signature verification.
     *      Dynamic types (bytes) are hashed with keccak256 as required by EIP-712.
     * @param metaTx The MetaTx struct to hash.
     * @return The keccak256 struct hash.
     */
    function _createStructHash(MetaTx memory metaTx) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                META_TX_TYPEHASH,
                metaTx.from,
                metaTx.target,
                keccak256(metaTx.data),
                metaTx.nonce,
                metaTx.deadline
            )
        );
    }
}