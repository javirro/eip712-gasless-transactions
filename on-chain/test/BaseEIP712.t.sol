// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {BaseEIP712} from "../src/EIP712/BaseEIP712.sol";

contract MockBaseEIP712 is BaseEIP712 {
    bytes32 public constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");

    constructor() BaseEIP712("MockBaseEIP712", "1") {}

    function getName() public view returns (string memory) {
        return _EIP712Name();
    }

    function getVersion() public view returns (string memory) {
        return _EIP712Version();
    }

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function exposeValidateSignature(address signer, bytes32 structHash, bytes memory signature) external {
        validateSignature(signer, structHash, signature);
    }

    function exposeVerifySignature(
        address signer,
        bytes32 structHash,
        bytes memory signature
    ) external view returns (bool) {
        return verifySignature(signer, structHash, signature);
    }

    function hashTypedData(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}

contract BaseEIP712Test is Test {
    MockBaseEIP712 public baseEIP712;
    bytes32 public constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant MAIL_TYPEHASH = keccak256("Mail(address from,address to,string contents)");
    string name = "MockBaseEIP712";
    string version = "1";

    uint256 internal signerPk;
    address internal signer;

    function setUp() public {
        baseEIP712 = new MockBaseEIP712();
        signerPk = 0xA11CE;
        signer = vm.addr(signerPk);
    }

    // ──────────────────────────────────────────────
    //  Helpers
    // ──────────────────────────────────────────────

    function _buildStructHash(address from, address to, string memory contents) internal pure returns (bytes32) {
        return keccak256(abi.encode(MAIL_TYPEHASH, from, to, keccak256(bytes(contents))));
    }

    function _signStructHash(bytes32 structHash, uint256 pk) internal view returns (bytes memory) {
        bytes32 digest = baseEIP712.hashTypedData(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ──────────────────────────────────────────────
    //  Domain separator & metadata
    // ──────────────────────────────────────────────

    function testDomainSeparator() public view {
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(TYPE_HASH, keccak256(bytes(name)), keccak256(bytes(version)), block.chainid, address(baseEIP712))
        );
        assertEq(baseEIP712.getDomainSeparator(), expectedDomainSeparator);
    }

    function testNameAndVersion() public view {
        assertEq(baseEIP712.getName(), name);
        assertEq(baseEIP712.getVersion(), version);
    }

    function testSignatureLengthConstant() public view {
        assertEq(baseEIP712.SIGNATURE_LENGTH(), 65);
    }

    // ──────────────────────────────────────────────
    //  validateSignature – success
    // ──────────────────────────────────────────────

    function testValidateSignature_Success() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        baseEIP712.exposeValidateSignature(signer, structHash, sig);
    }

    function testValidateSignature_EmitsEvent() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        vm.expectEmit(true, true, false, true);
        emit BaseEIP712.SignatureVerified(signer, structHash);

        baseEIP712.exposeValidateSignature(signer, structHash, sig);
    }

    // ──────────────────────────────────────────────
    //  validateSignature – reverts
    // ──────────────────────────────────────────────

    function testValidateSignature_RevertsOnZeroStructHash() public {
        bytes memory sig = new bytes(65);
        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidStructHash.selector);
        baseEIP712.exposeValidateSignature(signer, bytes32(0), sig);
    }

    function testValidateSignature_RevertsOnInvalidSignatureLength_TooShort() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = new bytes(64);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeValidateSignature(signer, structHash, sig);
    }

    function testValidateSignature_RevertsOnInvalidSignatureLength_TooLong() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = new bytes(66);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeValidateSignature(signer, structHash, sig);
    }

    function testValidateSignature_RevertsOnEmptySignature() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = new bytes(0);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeValidateSignature(signer, structHash, sig);
    }

    function testValidateSignature_RevertsOnZeroSigner() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSigner.selector);
        baseEIP712.exposeValidateSignature(address(0), structHash, sig);
    }

    function testValidateSignature_RevertsOnWrongSigner() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        address wrongSigner = vm.addr(0xB0B);
        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeValidateSignature(wrongSigner, structHash, sig);
    }

    function testValidateSignature_RevertsOnTamperedSignature() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);
        // Flip a byte in the signature
        sig[0] = sig[0] == bytes1(0x01) ? bytes1(0x02) : bytes1(0x01);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeValidateSignature(signer, structHash, sig);
    }

    function testValidateSignature_RevertsOnWrongStructHash() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        bytes32 differentStructHash = _buildStructHash(signer, address(0xBEEF), "Goodbye");
        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeValidateSignature(signer, differentStructHash, sig);
    }

    // ──────────────────────────────────────────────
    //  verifySignature – success
    // ──────────────────────────────────────────────

    function testVerifySignature_ReturnsTrue() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        bool result = baseEIP712.exposeVerifySignature(signer, structHash, sig);
        assertTrue(result);
    }

    function testVerifySignature_ReturnsFalseOnWrongSigner() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        address wrongSigner = vm.addr(0xB0B);
        bool result = baseEIP712.exposeVerifySignature(wrongSigner, structHash, sig);
        assertFalse(result);
    }

    // ──────────────────────────────────────────────
    //  verifySignature – reverts
    // ──────────────────────────────────────────────

    function testVerifySignature_RevertsOnZeroStructHash() public {
        bytes memory sig = new bytes(65);
        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidStructHash.selector);
        baseEIP712.exposeVerifySignature(signer, bytes32(0), sig);
    }

    function testVerifySignature_RevertsOnInvalidSignatureLength() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = new bytes(64);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSignature.selector);
        baseEIP712.exposeVerifySignature(signer, structHash, sig);
    }

    function testVerifySignature_RevertsOnZeroSigner() public {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);

        vm.expectRevert(BaseEIP712.BaseEIP712__InvalidSigner.selector);
        baseEIP712.exposeVerifySignature(address(0), structHash, sig);
    }

    function testVerifySignature_ReturnsFalseOnTamperedSignature() public view {
        bytes32 structHash = _buildStructHash(signer, address(0xBEEF), "Hello");
        bytes memory sig = _signStructHash(structHash, signerPk);
        sig[0] = sig[0] == bytes1(0x01) ? bytes1(0x02) : bytes1(0x01);

        bool result = baseEIP712.exposeVerifySignature(signer, structHash, sig);
        assertFalse(result);
    }

    // ──────────────────────────────────────────────
    //  Fuzz tests
    // ──────────────────────────────────────────────

    function testFuzz_ValidateSignature(uint256 pk) public {
        pk = bound(pk, 1, type(uint128).max);
        address fuzzSigner = vm.addr(pk);

        bytes32 structHash = _buildStructHash(fuzzSigner, address(0xBEEF), "fuzz");
        bytes memory sig = _signStructHash(structHash, pk);

        baseEIP712.exposeValidateSignature(fuzzSigner, structHash, sig);
    }

    function testFuzz_VerifySignature(uint256 pk) public view {
        pk = bound(pk, 1, type(uint128).max);
        address fuzzSigner = vm.addr(pk);

        bytes32 structHash = _buildStructHash(fuzzSigner, address(0xBEEF), "fuzz");
        bytes memory sig = _signStructHash(structHash, pk);

        bool result = baseEIP712.exposeVerifySignature(fuzzSigner, structHash, sig);
        assertTrue(result);
    }
}
