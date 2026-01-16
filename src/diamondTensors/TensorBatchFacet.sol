// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "./TensorStorage.sol";
import {TensorPayload} from "./backends/TensorPayload.sol";

/// @title TensorBatchFacet
/// @notice Vectorized read/write operations for tensors.
/// @dev Enables tensor-as-RAM semantics.
contract TensorBatchFacet {
    event TensorBatchWrite(bytes32 indexed tensorId, uint256 count);

    /// @notice Batch set values across one or many tensors.
    /// @param keys TensorKey array (tensorId + flatIndex)
    /// @param values Values to write
    function batchSet(
        TensorStorage.TensorKey[] calldata keys,
        int256[] calldata values
    ) external {
        uint256 len = keys.length;
        require(len == values.length, "length mismatch");

        TensorStorage.Layout storage l = TensorStorage.layout();

        for (uint256 i = 0; i < len; i++) {
            TensorStorage.TensorKey calldata k = keys[i];
            require(l.meta[k.id].owner == msg.sender, "not owner");
            require(!TensorPayload.hasPayload(l, k.id), "payload immutable");
            require(!TensorPayload.hasPackedU8(l, k.id), "packed immutable");

            l.data[k.id][k.flatIndex] = values[i];
        }

        // Optional: emit per-tensor aggregation later
    }

    /// @notice Batch get values across one or many tensors.
    /// @param keys TensorKey array (tensorId + flatIndex)
    function batchGet(
        TensorStorage.TensorKey[] calldata keys
    ) external view returns (int256[] memory values) {
        uint256 len = keys.length;
        values = new int256[](len);

        TensorStorage.Layout storage l = TensorStorage.layout();

        for (uint256 i = 0; i < len; i++) {
            TensorStorage.TensorKey calldata k = keys[i];
            values[i] = TensorPayload.readValue(l, k.id, k.flatIndex);
        }
    }
}
