// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "./TensorStorage.sol";
import {SeedUtils} from "./SeedUtils.sol";
import {TensorPayload} from "./backends/TensorPayload.sol";

contract TensorReadFacet {
    function meta(bytes32 tensorId)
        external
        view
        returns (TensorStorage.TensorMeta memory)
    {
        return TensorStorage.layout().meta[tensorId];
    }

    function get(bytes32 tensorId, uint256 flatIndex)
        external
        view
        returns (int256)
    {
        TensorStorage.Layout storage l = TensorStorage.layout();
        return TensorPayload.readValue(l, tensorId, flatIndex);
    }

    function getAt(
        bytes32 tensorId,
        uint256[] calldata indices
    ) external view returns (int256) {
        TensorStorage.Layout storage l = TensorStorage.layout();
        uint256 idx =
            SeedUtils.flattenIndex(l.meta[tensorId].shape, indices);
        return TensorPayload.readValue(l, tensorId, idx);
    }
}
