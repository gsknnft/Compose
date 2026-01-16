// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

    error RankMismatch();
    error IndexOutOfBounds();
    error InvalidShape();
    error SizeOverflow();
library SeedUtils {
    /// @notice Deterministic tensor id, stable across chains if inputs match.
    function tensorId(address owner, bytes32 seed, uint64 nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("TENSOR", owner, seed, nonce));
    }

    /// @notice Computes product(shape). Reverts on overflow or empty dims.
    function computeSize(uint256[] memory shape) internal pure returns (uint256 size) {
        if (shape.length == 0) revert InvalidShape();
        size = 1;
        for (uint256 i = 0; i < shape.length; i++) {
            uint256 d = shape[i];
            if (d == 0) revert InvalidShape();
            // overflow-safe multiply
            uint256 next = size * d;
            if (d != 0 && next / d != size) revert SizeOverflow();
            size = next;
        }
    }

    /// @notice Flattens N-D indices into a single index (row-major, dim0 fastest).
    function flattenIndex(uint256[] memory shape, uint256[] memory indices)
        internal
        pure
        returns (uint256 idx)
    {
        if (shape.length != indices.length) revert RankMismatch();

        uint256 stride = 1;
        for (uint256 i = 0; i < shape.length; i++) {
            uint256 dim = shape[i];
            uint256 ind = indices[i];
            if (ind >= dim) revert IndexOutOfBounds();

            unchecked {
                idx += ind * stride;
                stride *= dim;
            }
        }
    }
}