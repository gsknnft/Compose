// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibCapsuleStorage
/// @notice Canonical Diamond storage for tensor capsule registry.
/// @dev Append-only: NEVER reorder fields. Only append.
/// WIP and on hold until capsule facet is stable. - using unified TensorStorage for now.

library LibCapsuleStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("diamond.tensor.capsule.storage.v1");

    struct CapsuleRecord {
        bytes32 capsuleRoot;
        uint64 timestamp;
        address owner;
    }

    struct Layout {
        /// @notice tensorId => latest capsule root
        mapping(bytes32 => bytes32) latestCapsule;

        /// @notice tensorId => full capsule lineage
        mapping(bytes32 => CapsuleRecord[]) registry;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
