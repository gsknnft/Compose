// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface for pluggable tensor backends.
interface ITensorBackend {
    function writeTensor(bytes32 tensorId, bytes calldata payload) external;
    function readTensor(bytes32 tensorId) external view returns (bytes memory);
    function readAt(
        bytes32 tensorId,
        uint256 offset,
        uint256 length
    ) external view returns (bytes memory);
}
