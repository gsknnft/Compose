// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TensorStorage
/// @notice Canonical storage layout for DiamondTensorCore (shared by all facets).
/// @dev Append-only rule: NEVER reorder fields inside Layout. Only append new fields.
library TensorStorage {
    /// @notice Storage slot for the entire tensor system (DiamondStorage-style).
    bytes32 internal constant STORAGE_SLOT =
        keccak256("diamond.tensor.core.storage.v1");

    // -------------------------------------------------------------------------
    // Ergonomic / typed tensor descriptors (views, not separate storage)
    // -------------------------------------------------------------------------

    struct TensorKey {
        bytes32 id;
        uint256 flatIndex;
    }

    struct Tensor1d {
        bytes32 id;
        uint256 length;
    }

    struct Tensor2d {
        bytes32 id;
        uint256 rows;
        uint256 cols;
    }

    struct Tensor3d {
        bytes32 id;
        uint256 dim1;
        uint256 dim2;
        uint256 dim3;
    }

    struct Tensor4d {
        bytes32 id;
        uint256 dim1;
        uint256 dim2;
        uint256 dim3;
        uint256 dim4;
    }

    struct CapsuleRecord {
        bytes32 capsuleRoot;
        uint64 timestamp;
        address owner;
    }

    struct NFTBinding {
        address nft;
        uint256 tokenId;
        bytes32 tensorId;
        bool immutableBinding;
        uint64 boundAt;
    }

    // -------------------------------------------------------------------------
    // Core metadata
    // -------------------------------------------------------------------------

    struct TensorMeta {
        bytes32 id;
        address owner;

        /// @dev rank = shape.length; stored for convenience and cheap checks.
        uint8 rank;

        /// @dev Shape is dynamic; always treat as canonical source for strides.
        uint256[] shape;

        /// @dev product(shape). Precomputed to validate flatIndex bounds cheaply.
        uint256 size;

        /// @dev creation time (for lineage / auditing / snapshots).
        uint64 createdAt;

        /// @dev reserved for future packing / flags without breaking layout.
        uint32 flags;

        /// @dev reserved for future expansions.
        uint128 reserved;
    }

    struct Layout {
        // tensorId => metadata
        mapping(bytes32 => TensorMeta) meta;

        // tensorId => flatIndex => value
        mapping(bytes32 => mapping(uint256 => int256)) data;

        // owner => tensorIds
        mapping(address => bytes32[]) owned;

        // tensorId => exists
        mapping(bytes32 => bool) exists;

        // owner => seed => lastNonce (optional deterministic id mgmt)
        mapping(address => mapping(bytes32 => uint64)) nonces;

        /// @notice tensorId => latest capsule root
        mapping(bytes32 => bytes32) latestCapsule;
        
        /// @notice tensorId => full capsule lineage
        /// @notice Capsule lineage is stored alongside tensor state by design.
        /// @dev This couples memory and provenance intentionally for v1.
        ///      Future versions MAY extract this into a separate storage namespace.
        mapping(bytes32 => CapsuleRecord[]) registry;

        /// @notice nft => tokenId => binding
        mapping(address => mapping(uint256 => NFTBinding)) bindings;

        /// @notice tensorId => SSTORE2-style payload chunks (optional backend)
        mapping(bytes32 => address[]) payloadChunks;

        /// @notice tensorId => packed uint8 payload words (32 elements per slot)
        mapping(bytes32 => uint256[]) packedU8;

        /// @notice tensorId => packed uint8 backend enabled
        mapping(bytes32 => bool) packedU8Exists;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}