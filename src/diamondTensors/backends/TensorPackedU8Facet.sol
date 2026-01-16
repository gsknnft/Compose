// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "../TensorStorage.sol";
import {TensorPayload} from "./TensorPayload.sol";

/// @title TensorPackedU8Facet
/// @notice Stores uint8 payloads packed 32 elements per slot.
contract TensorPackedU8Facet {
    event TensorPackedU8Written(
        bytes32 indexed tensorId,
        uint256 bytesLength,
        uint256 words
    );

    /// @notice Write a packed uint8 payload (immutable once stored).
    /// @dev Payload length must equal tensor size (1 byte per element).
    function writePackedU8(bytes32 tensorId, bytes calldata payload) external {
        TensorStorage.Layout storage l = TensorStorage.layout();
        TensorStorage.TensorMeta storage m = l.meta[tensorId];

        require(l.exists[tensorId], "tensor missing");
        require(m.owner == msg.sender, "not owner");
        require(!TensorPayload.hasPayload(l, tensorId), "payload exists");
        require(!l.packedU8Exists[tensorId], "packed exists");
        require(payload.length == m.size, "payload size mismatch");

        uint256 wordCount = (payload.length + 31) >> 5;
        uint256[] storage words = l.packedU8[tensorId];

        assembly {
            sstore(words.slot, wordCount)

            mstore(0x00, words.slot)
            let base := keccak256(0x00, 0x20)
            let idx := 0
            let ptr := payload.offset
            let end := add(ptr, payload.length)
            for { } lt(ptr, end) { } {
                let word := calldataload(ptr)
                sstore(add(base, idx), word)
                idx := add(idx, 1)
                ptr := add(ptr, 0x20)
            }
        }

        l.packedU8Exists[tensorId] = true;

        emit TensorPackedU8Written(tensorId, payload.length, wordCount);
    }

    /// @notice Read full packed uint8 payload as bytes.
    function readPackedU8(bytes32 tensorId)
        external
        view
        returns (bytes memory out)
    {
        TensorStorage.Layout storage l = TensorStorage.layout();
        require(l.packedU8Exists[tensorId], "packed missing");

        uint256 size = l.meta[tensorId].size;
        out = new bytes(size);

        uint256[] storage words = l.packedU8[tensorId];
        uint256 wordCount = words.length;

        for (uint256 i = 0; i < wordCount; i++) {
            uint256 word = words[i];
            assembly {
                mstore(add(out, add(0x20, shl(5, i))), word)
            }
        }
    }

    function packedU8WordCount(bytes32 tensorId)
        external
        view
        returns (uint256)
    {
        return TensorStorage.layout().packedU8[tensorId].length;
    }
}
