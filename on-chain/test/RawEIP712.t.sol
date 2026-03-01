// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {RawEIP712} from "../src/EIP712/RawEIP7112.sol";

contract MockRawEIP712 is RawEIP712 {
    bytes32 public constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");

    constructor() RawEIP712("MockRawEIP712", "1") {}

    function exposeValidateSignature(address signer, bytes32 structHash, uint8 v, bytes32 r, bytes32 s) external {
        validateSignature(signer, structHash, v, r, s);
    }

    function exposeDomainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    function exposeHashTypedData(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedData(structHash);
    }
}

contract RawEIP712Test is Test {
    MockRawEIP712 public rawEIP712;

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");
    bytes32 public constant HALF_CURVE_ORDER =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    string name = "MockRawEIP712";
    string version = "1";

    uint256 internal signerPk;
    address internal signer;

    function setUp() public {
        rawEIP712 = new MockRawEIP712();
        signerPk = 0xA11CE;
        signer = vm.addr(signerPk);
    }

    // ──────────────────────────────────────────────
    //  Helpers
    // ──────────────────────────────────────────────

    function _buildStructHash(address from, address to, string memory contents) internal pure returns (bytes32) {
        return keccak256(abi.encode(MAIL_TYPEHASH, from, to, keccak256(bytes(contents))));
    }

    function _signStructHash(bytes32 structHash, uint256 pk) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 digest = rawEIP712.exposeHashTypedData(structHash);
        (v, r, s) = vm.sign(pk, digest);
    }

    // ──────────────────────────────────────────────
    //  Constructor / immutables
    // ──────────────────────────────────────────────

    function testNameHash() public view {
        assertEq(rawEIP712.NAME_HASH(), keccak256(bytes(name)));
    }

    function testVersionHash() public view {
        assertEq(rawEIP712.VERSION_HASH(), keccak256(bytes(version)));
    }

    function testDomainTypehash() public view {
        assertEq(rawEIP712.DOMAIN_TYPEHASH(), DOMAIN_TYPEHASH);
    }

    // ──────────────────────────────────────────────
    //  Domain separator
    // ──────────────────────────────────────────────

    function testDomainSeparator() public view {
        bytes32 expected = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(rawEIP712)
            )
        );
        assertEq(rawEIP712.exposeDomainSeparator(), expected);
    }

    function testDomainSeparator_RecomputesOnChainIdChange() public {
        bytes32 originalSeparator = rawEIP712.exposeDomainSeparator();

        // Fork to a new chain ID
        vm.chainId(12345);

        bytes32 newSeparator = rawEIP712.exposeDomainSeparator();
        assertTrue(newSeparator != originalSeparator, "separator should change with chain id");

        bytes32 expected = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                12345,
                address(rawEIP712)
            )
        );
        assertEq(newSeparator, expected);
    }

    // ──────────────────────────────────────────────
    //  _hashTypedData
    // ──────────────────────────────────────────────

    function testHashTypedData() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes32 digest = rawEIP712.exposeHashTypedData(structHash);

        bytes32 expected = keccak256(
            abi.encodePacked("\x19\x01", rawEIP712.exposeDomainSeparator(), structHash)
        );
        assertEq(digest, expected);
    }

    // ──────────────────────────────────────────────
    //  validateSignature – success
    // ──────────────────────────────────────────────

    function testValidateSignature_Success() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        rawEIP712.exposeValidateSignature(signer, structHash, v, r, s);
    }

    function testValidateSignature_EmitsEvent() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        vm.expectEmit(true, true, false, true);
        emit RawEIP712.SignatureVerified(signer, structHash);

        rawEIP712.exposeValidateSignature(signer, structHash, v, r, s);
    }

    // ──────────────────────────────────────────────
    //  validateSignature – reverts
    // ──────────────────────────────────────────────

    function testValidateSignature_RevertsOnZeroSigner() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        vm.expectRevert(RawEIP712.RawEIP712__InvalidSigner.selector);
        rawEIP712.exposeValidateSignature(address(0), structHash, v, r, s);
    }

    function testValidateSignature_RevertsOnZeroStructHash() public {
        vm.expectRevert(RawEIP712.RawEIP712__InvalidStructHash.selector);
        rawEIP712.exposeValidateSignature(signer, bytes32(0), 27, bytes32(0), bytes32(0));
    }

    function testValidateSignature_RevertsOnHighS() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");

        // s value above HALF_CURVE_ORDER
        bytes32 highS = bytes32(uint256(HALF_CURVE_ORDER) + 1);

        vm.expectRevert(RawEIP712.RawEIP712__InvalidCurveHalfOrder.selector);
        rawEIP712.exposeValidateSignature(signer, structHash, 27, bytes32(uint256(1)), highS);
    }

    function testValidateSignature_RevertsOnWrongSigner() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        address wrongSigner = vm.addr(0xB0B);
        vm.expectRevert(RawEIP712.RawEIP712__InvalidSignature.selector);
        rawEIP712.exposeValidateSignature(wrongSigner, structHash, v, r, s);
    }

    function testValidateSignature_RevertsOnInvalidSignature() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");

        // Provide r = 0 and s = 0 which leads to ecrecover returning address(0)
        vm.expectRevert(RawEIP712.RawEIP712__InvalidSignature.selector);
        rawEIP712.exposeValidateSignature(signer, structHash, 27, bytes32(0), bytes32(0));
    }

    // ──────────────────────────────────────────────
    //  verifySignature – success
    // ──────────────────────────────────────────────

    function testVerifySignature_ReturnsTrue() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        bool result = rawEIP712.verifySignature(signer, structHash, v, r, s);
        assertTrue(result);
    }

    // ──────────────────────────────────────────────
    //  verifySignature – false
    // ──────────────────────────────────────────────

    function testVerifySignature_ReturnsFalseOnZeroSigner() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        bool result = rawEIP712.verifySignature(address(0), structHash, v, r, s);
        assertFalse(result);
    }

    function testVerifySignature_ReturnsFalseOnZeroStructHash() public view {
        bool result = rawEIP712.verifySignature(signer, bytes32(0), 27, bytes32(0), bytes32(0));
        assertFalse(result);
    }

    function testVerifySignature_ReturnsFalseOnHighS() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes32 highS = bytes32(uint256(HALF_CURVE_ORDER) + 1);

        bool result = rawEIP712.verifySignature(signer, structHash, 27, bytes32(uint256(1)), highS);
        assertFalse(result);
    }

    function testVerifySignature_ReturnsFalseOnWrongSigner() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, signerPk);

        address wrongSigner = vm.addr(0xB0B);
        bool result = rawEIP712.verifySignature(wrongSigner, structHash, v, r, s);
        assertFalse(result);
    }

    // ──────────────────────────────────────────────
    //  Fuzz tests
    // ──────────────────────────────────────────────

    function testFuzz_ValidateSignature(uint256 pk) public {
        pk = bound(pk, 1, type(uint128).max);
        address fuzzSigner = vm.addr(pk);

        bytes32 structHash = _buildStructHash(fuzzSigner, address(0xBEEF), "fuzz");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, pk);

        rawEIP712.exposeValidateSignature(fuzzSigner, structHash, v, r, s);
    }

    function testFuzz_VerifySignature(uint256 pk) public view {
        pk = bound(pk, 1, type(uint128).max);
        address fuzzSigner = vm.addr(pk);

        bytes32 structHash = _buildStructHash(fuzzSigner, address(0xBEEF), "fuzz");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, pk);

        bool result = rawEIP712.verifySignature(fuzzSigner, structHash, v, r, s);
        assertTrue(result);
    }

    function testFuzz_VerifySignature_WrongSigner(uint256 pk1, uint256 pk2) public view {
        pk1 = bound(pk1, 1, type(uint128).max);
        pk2 = bound(pk2, 1, type(uint128).max);
        vm.assume(pk1 != pk2);

        address signer1 = vm.addr(pk1);
        address signer2 = vm.addr(pk2);

        bytes32 structHash = _buildStructHash(signer1, address(0xBEEF), "fuzz");
        (uint8 v, bytes32 r, bytes32 s) = _signStructHash(structHash, pk1);

        bool result = rawEIP712.verifySignature(signer2, structHash, v, r, s);
        assertFalse(result);
    }
}
