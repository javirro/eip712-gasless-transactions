// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title BaseEIP712
 * @dev A base contract for implementing EIP-712 typed data signing and verification.
 *      This contract extends OpenZeppelin's EIP712 implementation and provides additional functionality for signature validation.
 *      It can be extended by other contracts to implement specific typed data structures and logic.
 */
abstract contract BaseEIP712 is EIP712 {
    using ECDSA for bytes32;

    uint8 public constant SIGNATURE_LENGTH = 65;

    error BaseEIP712__InvalidSignature();
    error BaseEIP712__InvalidCurveHalfOrder();
    error BaseEIP712__InvalidSigner();
    error BaseEIP712__InvalidStructHash();

    event SignatureVerified(address indexed signer, bytes32 indexed structHash);

    constructor(string memory name, string memory version) EIP712(name, version) {}

    /** @dev Validates the EIP-712 signature for the given signer and struct hash.
     * @param signer The address of the expected signer of the message.
     * @param structHash The hash of the structured data being signed (the "message").
     * @param signature The ECDSA signature to validate against the struct hash and signer.
     */
    function validateSignature(address signer, bytes32 structHash, bytes memory signature) internal {
        if (structHash == bytes32(0)) revert BaseEIP712__InvalidStructHash();
        if (uint8(signature.length) != SIGNATURE_LENGTH) revert BaseEIP712__InvalidSignature();
        if (signer == address(0)) revert BaseEIP712__InvalidSigner();
        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = digest.recover(signature);
        if (recoveredSigner != signer) revert BaseEIP712__InvalidSignature();
        emit SignatureVerified(signer, structHash);
    }

    /** @dev Verifies the EIP-712 signature for the given signer and struct hash, returning a boolean result instead of reverting on failure.
    * @param signer The address of the expected signer of the message.
    * @param structHash The hash of the structured data being signed (the "message").
    * @param signature The ECDSA signature to verify against the struct hash and signer.
    * @return A boolean indicating whether the signature is valid for the given signer and struct hash.
    */
    function verifySignature(address signer, bytes32 structHash, bytes memory signature) internal view returns (bool) {
        if (structHash == bytes32(0)) revert BaseEIP712__InvalidStructHash();
        if (uint8(signature.length) != SIGNATURE_LENGTH) revert BaseEIP712__InvalidSignature();
        if (signer == address(0)) revert BaseEIP712__InvalidSigner();

        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = digest.recover(signature);
        if (recoveredSigner == address(0)) revert BaseEIP712__InvalidSignature();
        return recoveredSigner == signer;
    }

}

