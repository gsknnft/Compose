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
        if (len == 0) {
            return;
        }

        TensorStorage.Layout storage l = TensorStorage.layout();

        bytes32[] memory checkedIds = new bytes32[](len);
        uint256 checkedCount;
        bytes32 singleId;

        for (uint256 i; i < len; ) {
            bytes32 id = keys[i].id;

            bool seen;
            for (uint256 j; j < checkedCount; ) {
                if (checkedIds[j] == id) {
                    seen = true;
                    break;
                }
                unchecked {
                    j++;
                }
            }

            if (!seen) {
                TensorStorage.TensorMeta storage meta = l.meta[id];
                require(meta.owner == msg.sender, "not owner");
                require(!TensorPayload.hasPayload(l, id), "payload immutable");
                require(!TensorPayload.hasPackedU8(l, id), "packed immutable");

                checkedIds[checkedCount] = id;
                if (checkedCount == 0) {
                    singleId = id;
                } else if (singleId != id) {
                    singleId = bytes32(0);
                }
                unchecked {
                    checkedCount++;
                }
            }

            unchecked {
                i++;
            }
        }

        if (singleId != bytes32(0)) {
            mapping(uint256 => int256) storage slots = l.data[singleId];
            for (uint256 i; i < len; ) {
                slots[keys[i].flatIndex] = values[i];
                unchecked {
                    i++;
                }
            }
        } else {
            for (uint256 i; i < len; ) {
                TensorStorage.TensorKey calldata k = keys[i];
                l.data[k.id][k.flatIndex] = values[i];

                unchecked {
                    i++;
                }
            }
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
