// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

/**
 * @title RawEIP712
 * @dev A base contract for implementing EIP-712 typed data signing and verification.
 *      This contract provides the core functionality for domain separation and signature validation.
 *      It can be extended by other contracts to implement specific typed data structures and logic.
 */
abstract contract RawEIP712 {

  /** @dev The constant HALF_CURVE_ORDER is used to enforce the "low s" requirement for ECDSA signatures.
   *      This is a security measure to prevent signature malleability, ensuring that each message has a unique valid signature.
   *      The value is derived from the secp256k1 curve parameters and represents half of the curve's order.
   *      ECDSA curve creates two valid signatures for each message, but only one is considered canonical.
   */
  bytes32 private constant HALF_CURVE_ORDER =
    0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public immutable NAME_HASH;
    bytes32 public immutable VERSION_HASH;
    uint256 private immutable _CACHED_CHAIN_ID;
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;

    event SignatureVerified(address indexed signer, bytes32 indexed structHash);


    error RawEIP712__InvalidSignature();
    error RawEIP712__InvalidCurveHalfOrder();
    error RawEIP712__InvalidSigner();
    error RawEIP712__InvalidStructHash();

    constructor(string memory name, string memory version) {
        NAME_HASH = keccak256(bytes(name));
        VERSION_HASH = keccak256(bytes(version));
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

  /**
   * @dev Computes the domain separator for the current chain and contract.
   *      Caches the result for efficiency, but recomputes if the chain ID changes (e.g., due to a fork).
   * @return The domain separator as a bytes32 hash.
   */
    function _domainSeparator() internal view returns (bytes32) {
    if (block.chainid == _CACHED_CHAIN_ID) return _CACHED_DOMAIN_SEPARATOR;
    return _buildDomainSeparator();
  }

    /**
     * @dev Builds the domain separator using the EIP-712 domain type hash and the contract's name, version, chain ID, and address.
     *      This function is called during construction to initialize the cached domain separator and can be called later if the chain ID changes.
     * @return The computed domain separator as a bytes32 hash.
     */
    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                NAME_HASH,
                VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Hashes the typed data struct using the domain separator and the struct hash. It is used to create the digest that will be signed or verified.
     * @param structHash The hash of the typed data struct (e.g., keccak256 of the encoded struct).
     * @return The final digest as a bytes32 hash that can be signed or verified.
     */
    function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
      // EIP-712 magic prefix to prevent collision with regular signatures
      bytes memory encodedData = abi.encodePacked("\x19\x01", _domainSeparator(), structHash);
      bytes32 digest = keccak256(encodedData);
      return digest;
    }

    /**
     * @dev Validates the signature for the given signer and struct hash.
     * @param signer The address of the expected signer of the message.
     * @param structHash The hash of the typed data struct that was signed.
     * @param v The recovery byte of the signature (27 or 28).
     * @param r The r component of the signature.
     * @param s The s component of the signature.
     */
    function validateSignature(address signer, bytes32 structHash, uint8 v, bytes32 r, bytes32 s) internal  {
        if (signer == address(0)) revert RawEIP712__InvalidSigner();
        if (structHash == bytes32(0)) revert RawEIP712__InvalidStructHash();
        if (uint256(s) > uint256(HALF_CURVE_ORDER))  revert RawEIP712__InvalidCurveHalfOrder();
        bytes32 digest = _hashTypedData(structHash);
        address recoveredSigner = ecrecover(digest, v, r, s);
        if (recoveredSigner == address(0)) revert RawEIP712__InvalidSignature();
        if (recoveredSigner != signer) revert RawEIP712__InvalidSignature();
        emit SignatureVerified(signer, structHash);
    }


    /** @dev A public function to verify a signature against a signer and struct hash. This can be used for testing or external verification.
     * @param signer The address of the expected signer of the message.
     * @param structHash The hash of the typed data struct that was signed.
     * @param v The recovery byte of the signature (27 or 28).
     * @param r The r component of the signature.
     * @param s The s component of the signature.
     * @return A boolean indicating whether the signature is valid for the given signer and struct hash.
     */
    function verifySignature(address signer, bytes32 structHash, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        if (signer == address(0)) return false;
        if (structHash == bytes32(0)) return false;
        if (uint256(s) > uint256(HALF_CURVE_ORDER)) return false;
        bytes32 digest = _hashTypedData(structHash);
        address recoveredSigner = ecrecover(digest, v, r, s);
        bool isValid = recoveredSigner == signer;
        return isValid;
    }
}
