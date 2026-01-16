// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TensorStorage.sol";
import "../backends/TensorPayloadMod.sol";

/// @title CapsuleFacet
/// @notice Freezes tensor state into a verifiable capsule hash.
/// @dev Capsules are immutable statements of memory, not executable logic.
contract CapsuleFacet {
    /// @notice Emitted when a tensor is frozen into a capsule.
    /// @param tensorId The source tensor
    /// @param capsuleRoot Hash representing frozen state
    /// @param owner Tensor owner
    /// @param timestamp Block timestamp
    event CapsuleCreated(
        bytes32 indexed tensorId,
        bytes32 indexed capsuleRoot,
        address indexed owner,
        uint64 timestamp
    );

    /// -----------------------------------------------------------------------
    /// Capsule creation
    /// -----------------------------------------------------------------------

    /// @notice Freeze a tensor into a capsule hash.
    /// @dev This does NOT modify tensor storage.
    /// @param tensorId The tensor to freeze
    /// @return capsuleRoot Deterministic hash of tensor state
    function freezeTensor(bytes32 tensorId)
        external
        view
        returns (bytes32 capsuleRoot)
    {
        TensorStorage.Layout storage l = TensorStorage.layout();
        TensorStorage.TensorMeta storage m = l.meta[tensorId];

        require(l.exists[tensorId], "tensor missing");
        require(m.owner == msg.sender, "not owner");

        capsuleRoot = _computeCapsuleRoot(tensorId, m);
    }

    /// -----------------------------------------------------------------------
    /// Internal hashing
    /// -----------------------------------------------------------------------

    function _computeCapsuleRoot(
        bytes32 tensorId,
        TensorStorage.TensorMeta storage m
    ) internal view returns (bytes32) {
        TensorStorage.Layout storage l = TensorStorage.layout();

        bytes32 h = keccak256(
            abi.encodePacked(
                "CAPSULE_V1",
                tensorId,
                m.owner,
                m.rank,
                m.shape,
                m.size,
                m.createdAt
            )
        );

        // fold tensor values
        for (uint256 i = 0; i < m.size; i++) {
            h = keccak256(
                abi.encodePacked(
                    h,
                    i,
                    TensorPayloadMod.readValue(l, tensorId, i)
                )
            );
        }

        return h;
    }

    /// -----------------------------------------------------------------------
    /// Public helper (event emission wrapper)
    /// -----------------------------------------------------------------------

    /// @notice Freeze tensor and emit capsule event.
    /// @dev Use this for indexing / off-chain sync.
    function emitCapsule(bytes32 tensorId) external returns (bytes32 root) {
        TensorStorage.Layout storage l = TensorStorage.layout();
        TensorStorage.TensorMeta storage m = l.meta[tensorId];

        require(l.exists[tensorId], "tensor missing");
        require(m.owner == msg.sender, "not owner");

        root = _computeCapsuleRoot(tensorId, m);

        emit CapsuleCreated(
            tensorId,
            root,
            msg.sender,
            uint64(block.timestamp)
        );
    }
}
