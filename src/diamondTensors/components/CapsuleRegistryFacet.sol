// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TensorStorage.sol";

/// @title CapsuleRegistryFacet
/// @notice Append-only registry for capsule roots and lineage.
contract CapsuleRegistryFacet {

    event CapsuleRegistered(
        bytes32 indexed tensorId,
        bytes32 indexed capsuleRoot,
        address indexed owner,
        uint64 timestamp,
        uint256 index
    );

    /// ---------------------------------------------------------------------
    /// Register
    /// ---------------------------------------------------------------------

    /// @notice Register a capsule root for a tensor.
    /// @dev Does not verify capsule content; assumes prior freeze.
    function registerCapsule(
        bytes32 tensorId,
        bytes32 capsuleRoot
    ) external {
        TensorStorage.Layout storage l = TensorStorage.layout();
        require(l.exists[tensorId], "tensor missing");
        require(l.meta[tensorId].owner == msg.sender, "not owner");

        uint64 ts = uint64(block.timestamp);
        uint256 index = l.registry[tensorId].length;

        l.registry[tensorId].push(
            TensorStorage.CapsuleRecord({
                capsuleRoot: capsuleRoot,
                timestamp: ts,
                owner: msg.sender
            })
        );
        l.latestCapsule[tensorId] = capsuleRoot;

        emit CapsuleRegistered(
            tensorId,
            capsuleRoot,
            msg.sender,
            ts,
            index
        );
    }

    /// ---------------------------------------------------------------------
    /// Views
    /// ---------------------------------------------------------------------

    function capsuleCount(bytes32 tensorId)
        external
        view
        returns (uint256)
    {
        return TensorStorage.layout().registry[tensorId].length;
    }

    function capsuleAt(bytes32 tensorId, uint256 index)
        external
        view
        returns (TensorStorage.CapsuleRecord memory)
    {
        return TensorStorage.layout().registry[tensorId][index];
    }

    function latestCapsule(bytes32 tensorId)
        external
        view
        returns (TensorStorage.CapsuleRecord memory)
    {
        TensorStorage.Layout storage l = TensorStorage.layout();
        uint256 len = l.registry[tensorId].length;
        require(len > 0, "no capsules");
        return l.registry[tensorId][len - 1];
    }
}
