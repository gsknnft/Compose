// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "./TensorStorage.sol";
import {TensorPayload} from "./backends/TensorPayload.sol";
import {SeedUtils} from "./SeedUtils.sol";

contract TensorWriteFacet {
    event TensorWrite(bytes32 indexed tensorId, uint256 index, int256 value);

    function set(
        bytes32 tensorId,
        uint256 flatIndex,
        int256 value
    ) external {
        TensorStorage.Layout storage l = TensorStorage.layout();
        require(l.meta[tensorId].owner == msg.sender, "not owner");
        require(!TensorPayload.hasPayload(l, tensorId), "payload immutable");
        require(!TensorPayload.hasPackedU8(l, tensorId), "packed immutable");

        l.data[tensorId][flatIndex] = value;
        emit TensorWrite(tensorId, flatIndex, value);
    }

    function setAt(
        bytes32 tensorId,
        uint256[] calldata indices,
        int256 value
    ) external {
        TensorStorage.Layout storage l = TensorStorage.layout();
        require(l.meta[tensorId].owner == msg.sender, "not owner");
        require(!TensorPayload.hasPayload(l, tensorId), "payload immutable");
        require(!TensorPayload.hasPackedU8(l, tensorId), "packed immutable");

        uint256 idx =
            SeedUtils.flattenIndex(l.meta[tensorId].shape, indices);

        l.data[tensorId][idx] = value;
        emit TensorWrite(tensorId, idx, value);
    }
}
