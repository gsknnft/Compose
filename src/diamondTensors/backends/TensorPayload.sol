// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "../TensorStorage.sol";

/// @notice Helpers for reading tensor payloads stored as SSTORE2-style chunks.
library TensorPayload {
    uint256 internal constant ELEMENT_BYTES = 32;
    uint256 internal constant CHUNK_BYTES = 24_576; // EIP-170 code size limit

    function chunkBytes() internal pure returns (uint256) {
        return CHUNK_BYTES;
    }

    function hasPayload(TensorStorage.Layout storage l, bytes32 tensorId)
        internal
        view
        returns (bool)
    {
        return l.payloadChunks[tensorId].length != 0;
    }

    function hasPackedU8(TensorStorage.Layout storage l, bytes32 tensorId)
        internal
        view
        returns (bool)
    {
        return l.packedU8Exists[tensorId];
    }

    function payloadLength(TensorStorage.Layout storage l, bytes32 tensorId)
        internal
        view
        returns (uint256)
    {
        uint256 size = l.meta[tensorId].size;
        uint256 total = size * ELEMENT_BYTES;
        require(size == 0 || total / ELEMENT_BYTES == size, "payload size overflow");
        return total;
    }

    function readValue(
        TensorStorage.Layout storage l,
        bytes32 tensorId,
        uint256 flatIndex
    ) internal view returns (int256 value) {
        uint256 size = l.meta[tensorId].size;
        if (size == 0 || flatIndex >= size) {
            return 0;
        }

        if (hasPackedU8(l, tensorId)) {
            return readPackedU8Value(l, tensorId, flatIndex, size);
        }

        if (!hasPayload(l, tensorId)) {
            return l.data[tensorId][flatIndex];
        }

        uint256 offset = flatIndex * ELEMENT_BYTES;
        uint256 chunkIndex = offset / CHUNK_BYTES;
        uint256 chunkOffset = offset % CHUNK_BYTES;
        address[] storage chunks = l.payloadChunks[tensorId];
        require(chunkIndex < chunks.length, "payload oob");

        address chunk = chunks[chunkIndex];
        uint256 chunkSize;
        assembly {
            chunkSize := extcodesize(chunk)
        }
        require(chunkOffset + ELEMENT_BYTES <= chunkSize, "payload oob");

        assembly {
            let ptr := mload(0x40)
            extcodecopy(chunk, ptr, chunkOffset, ELEMENT_BYTES)
            value := mload(ptr)
        }
    }

    function readPackedU8Value(
        TensorStorage.Layout storage l,
        bytes32 tensorId,
        uint256 flatIndex,
        uint256 size
    ) internal view returns (int256 value) {
        // Packed order matches abi.encodePacked(uint8[]) per 32-byte word.
        if (size == 0 || flatIndex >= size) {
            return 0;
        }

        uint256 wordIndex = flatIndex >> 5;
        uint256 byteIndex = flatIndex & 31;

        uint256[] storage words = l.packedU8[tensorId];
        if (wordIndex < words.length) {
            uint256 word = words[wordIndex];
            uint256 shift = (31 - byteIndex) << 3;
            uint256 byteVal = (word >> shift) & 0xff;
            return int256(byteVal);
        }
        return 0;
    }

    function readPayload(
        TensorStorage.Layout storage l,
        bytes32 tensorId
    ) internal view returns (bytes memory out) {
        uint256 total = payloadLength(l, tensorId);
        return readPayloadAt(l, tensorId, 0, total);
    }

    function readPayloadAt(
        TensorStorage.Layout storage l,
        bytes32 tensorId,
        uint256 offset,
        uint256 length
    ) internal view returns (bytes memory out) {
        address[] storage chunks = l.payloadChunks[tensorId];
        require(chunks.length != 0, "payload missing");

        uint256 total = payloadLength(l, tensorId);
        require(offset <= total, "payload oob");
        require(length <= total - offset, "payload oob");

        out = new bytes(length);
        uint256 remaining = length;
        uint256 cursor = offset;
        uint256 outOffset = 0;

        while (remaining > 0) {
            uint256 chunkIndex = cursor / CHUNK_BYTES;
            uint256 chunkOffset = cursor % CHUNK_BYTES;
            require(chunkIndex < chunks.length, "payload oob");

            address chunk = chunks[chunkIndex];
            uint256 chunkSize;
            assembly {
                chunkSize := extcodesize(chunk)
            }
            require(chunkOffset < chunkSize, "payload oob");

            uint256 available = chunkSize - chunkOffset;
            uint256 toCopy = remaining < available ? remaining : available;

            assembly {
                extcodecopy(
                    chunk,
                    add(out, add(0x20, outOffset)),
                    chunkOffset,
                    toCopy
                )
            }

            remaining -= toCopy;
            cursor += toCopy;
            outOffset += toCopy;
        }
    }
}
