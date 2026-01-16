// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "./TensorStorage.sol";

contract TensorFactory {
    function tensorsOf(address owner)
        external
        view
        returns (bytes32[] memory)
    {
        return TensorStorage.layout().owned[owner];
    }
}
