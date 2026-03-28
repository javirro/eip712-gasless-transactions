// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title TokenERC2612
 * @notice An ERC-20 token that implements the ERC-2612 permit extension for gasless approvals via EIP-712 signatures.
 * @dev  The EIP-712 belongs to the Token itself. No relayer contract is required. Any caller can submit a valid permit signature to set allowances on-chain.
 */
contract TokenERC2612 is ERC20, EIP712, IERC20Permit {
    using ECDSA for bytes32;

    uint8 public constant SIGNATURE_LENGTH = 65;


    /// @notice The EIP-712 type hash for the Permit struct (ERC-2612).
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    /**  @notice Separate type hash for transferWithPermit — includes `to`. It increases security by preventing signature reuse.
    */
    bytes32 public constant TRANSFER_WITH_PERMIT_TYPEHASH = keccak256(
        "TransferWithPermit(address from,address to,uint256 value,uint256 nonce,uint256 deadline)"
    );


    /// @notice Per-owner nonce used to prevent permit replay attacks.
    mapping(address => uint256) private _nonces;

    // Errors
    error TokenERC2612__InvalidSignature();
    error TokenERC2612__InvalidSigner();
    error TokenERC2612__InvalidStructHash();
    error TokenERC2612__ExpiredDeadline();

    // Events
    event SignatureVerified(address indexed signer, bytes32 indexed structHash);


    /**
     * @param name_    Token name (also used as the EIP-712 domain name).
     * @param symbol_  Token symbol.
     * @param version_ EIP-712 domain version string (e.g. "1").
     */
    constructor(string memory name_, string memory symbol_, string memory version_)
        ERC20(name_, symbol_)
        EIP712(name_, version_)
    {}

    /**
     * @notice Sets `value` as the allowance of `spender` over `owner`'s tokens,
     *         given a valid EIP-712 signature from `owner`.
     *
     * @dev The signature covers: owner, spender, value, nonce, deadline.
     *      On success the nonce for `owner` is incremented, preventing replay.
     *
     * @param owner    The token owner granting the allowance.
     * @param spender  The address being granted the allowance.
     * @param value    The amount of tokens to approve.
     * @param deadline Unix timestamp after which the permit is no longer valid.
     * @param v        Recovery byte of the ECDSA signature.
     * @param r        First 32 bytes of the ECDSA signature.
     * @param s        Second 32 bytes of the ECDSA signature.
     */
    function permit(address owner,address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        if (block.timestamp > deadline) revert TokenERC2612__ExpiredDeadline();
        bytes32 structHash = buildStructHash(owner, spender, value, _nonces[owner], deadline, PERMIT_TYPEHASH);

        // Encode (v, r, s) into a 65-byte signature for validateSignature
        bytes memory sig = abi.encodePacked(r, s, v);
        validateSignature(owner, structHash, sig);

        _nonces[owner]++;
        _approve(owner, spender, value);
    }

    /**
     * @notice Same as `permit` above but accepts a packed 65-byte signature
     *         instead of split (v, r, s) components.
     *
     * @dev Signature encoding: abi.encodePacked(r, s, v) — bytes [0..31] = r,
     *      bytes [32..63] = s, byte [64] = v. This matches the format used by
     *      ethers.js `signTypedData` and by validateSignature.
     *
     * @param owner     The token owner granting the allowance.
     * @param spender   The address being granted the allowance.
     * @param value     The amount of tokens to approve.
     * @param deadline  Unix timestamp after which the permit is no longer valid.
     * @param signature 65-byte packed ECDSA signature (r ++ s ++ v).
     */
    function permit(address owner,address spender,uint256 value,uint256 deadline, bytes memory signature) external {
        if (block.timestamp > deadline) revert TokenERC2612__ExpiredDeadline();

        bytes32 structHash = buildStructHash(owner, spender, value, _nonces[owner], deadline, PERMIT_TYPEHASH);

        validateSignature(owner, structHash, signature);

        _nonces[owner]++;
        _approve(owner, spender, value);
    }

    /**
    * @notice A convenience function that combines `permit` and `transferFrom` in a single call.
    * @param from      The token owner granting the allowance and source of tokens.
    * @param to        The recipient of the tokens.
    * @param value     The amount of tokens to transfer.
    * @param deadline  Unix timestamp after which the permit is no longer valid.
    * @param signature 65-byte packed ECDSA signature (r ++ s ++ v) from `from` authorizing the transfer.
    * @dev This function allows a spender to submit a permit and transfer tokens in one transaction, saving gas and improving UX.
     */
    function transferWithPermit(address from, address to, uint256 value, uint256 deadline, bytes memory signature) external {
        if (block.timestamp > deadline) revert TokenERC2612__ExpiredDeadline();

        // Uses a dedicated typehash that commits `to` inside the signed message.
        // This prevents the caller from redirecting the transfer to an arbitrary address
        // and avoids ambiguity with the standard permit() typehash.
        bytes32 structHash = buildStructHash(from, to, value, _nonces[from], deadline, TRANSFER_WITH_PERMIT_TYPEHASH);

        validateSignature(from, structHash, signature);

        _nonces[from]++;
        _transfer(from, to, value);
    }


    /**
     * @notice Validates a signature against a given struct hash and signer.
     * @param signer The address expected to have signed the message.
     * @param structHash The hash of the struct being signed.
     * @param signature The signature to validate.
     * @dev Reverts if the signature is invalid or does not match the signer.
     */
    function validateSignature(address signer, bytes32 structHash, bytes memory signature) internal {
        if (structHash == bytes32(0)) revert TokenERC2612__InvalidStructHash();
        if (signature.length != SIGNATURE_LENGTH) revert TokenERC2612__InvalidSignature();
        if (signer == address(0)) revert TokenERC2612__InvalidSigner();
        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = digest.recover(signature);
        if (recoveredSigner != signer) revert TokenERC2612__InvalidSignature();
        emit SignatureVerified(signer, structHash);
    }

    /**
    * @notice Builds the struct hash for the Permit or TransferWithPermit message.
    * @param owner The token owner (for Permit) or sender (for TransferWithPermit).
    * @param spender The spender (for Permit) or recipient (for TransferWithPermit).
    * @param value The amount of tokens to approve or transfer.
    * @param nonce The current nonce for the owner/sender.
    * @param deadline The deadline timestamp for the permit.
    * @param typeHash The EIP-712 type hash (PERMIT_TYPEHASH or TRANSFER_WITH_PERMIT_TYPEHASH).
    * @return The keccak256 hash of the encoded struct, ready for signing or signature verification.
     */
    function buildStructHash(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline, bytes32 typeHash) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
    }


    /// @inheritdoc IERC20Permit
    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }

    /// @inheritdoc IERC20Permit
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice Mints `amount` tokens to `to`. Not access-controlled — demo only.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
