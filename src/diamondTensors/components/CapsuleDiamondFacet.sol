// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CapsuleDiamondFacet
/// @notice Minimal facet-style contract for capsule verification and bounded tensor ops.
/// @dev This is a PoC scaffold for ERC-2535 diamond integration. It avoids external deps.
contract CapsuleDiamondFacet {
    address public owner;
    address public verifier; // external proof verifier (e.g., zk/optimistic light client)

    struct Capsule {
        bytes32 root;       // commitment to capsule contents
        bytes32 stateHash;  // commitment to state being teleported
        address sender;     // identity of capsule emitter
        uint64 nonce;       // replay protection per (domain, sender)
        uint64 srcChainId;  // source chain/domain id
        uint64 srcSlot;     // source slot/block height for finality anchoring
    }

    event CapsuleAccepted(bytes32 indexed root, bytes32 stateHash, address indexed sender, uint64 nonce);
    event VerifierUpdated(address indexed newVerifier);

    // replay guard: domain => sender => nonce consumed
    mapping(uint64 => mapping(address => mapping(uint64 => bool))) internal nonceUsed;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _verifier) {
        owner = msg.sender;
        verifier = _verifier;
    }

    function setVerifier(address _verifier) external onlyOwner {
        verifier = _verifier;
        emit VerifierUpdated(_verifier);
    }

    /// @notice Verify a capsule against an external proof verifier.
    /// @dev The verifier is expected to enforce validity of the proof; this facet only gates and emits.
    function submitCapsule(Capsule calldata c, bytes calldata proof) external returns (bool) {
        require(verifier != address(0), "verifier unset");
        require(msg.sender == c.sender, "sender mismatch");
        require(!nonceUsed[c.srcChainId][c.sender][c.nonce], "replay");
        require(proof.length <= 32_768, "proof too large"); // 32 KB cap to bound gas

        bool ok = IProofVerifier(verifier).verify(proof, c.root, c.stateHash);
        require(ok, "invalid proof");

        nonceUsed[c.srcChainId][c.sender][c.nonce] = true;
        emit CapsuleAccepted(c.root, c.stateHash, c.sender, c.nonce);
        return true;
    }

    /// @notice Bounded 2x2 matrix multiply to illustrate gas envelope for tiny tensor ops.
    /// @dev Pure function; inputs are row-major [a00,a01,a10,a11].
    function matmul2x2(uint256[4] memory a, uint256[4] memory b) external pure returns (uint256[4] memory c) {
        // c00 = a00*b00 + a01*b10
        c[0] = a[0] * b[0] + a[1] * b[2];
        // c01 = a00*b01 + a01*b11
        c[1] = a[0] * b[1] + a[1] * b[3];
        // c10 = a10*b00 + a11*b10
        c[2] = a[2] * b[0] + a[3] * b[2];
        // c11 = a10*b01 + a11*b11
        c[3] = a[2] * b[1] + a[3] * b[3];
    }
}

/// @notice External proof verifier interface; plug in zk/optimistic/light-client verifier.
interface IProofVerifier {
    function verify(bytes calldata proof, bytes32 root, bytes32 stateHash) external view returns (bool);
}
