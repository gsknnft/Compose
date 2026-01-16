// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "../TensorStorage.sol";
import {ITensorBackend} from "./ITensorBackend.sol";
import {TensorPayload} from "./TensorPayload.sol";

/// @title TensorSSTORE2Facet
/// @notice Stores dense tensor payloads as bytecode chunks (SSTORE2-style).
contract TensorSSTORE2Facet is ITensorBackend {
    event TensorPayloadWritten(
        bytes32 indexed tensorId,
        uint256 bytesLength,
        uint256 chunks
    );

    /// @notice Write an immutable payload for a tensor (int256 packed).
    function writeTensor(bytes32 tensorId, bytes calldata payload) external {
        TensorStorage.Layout storage l = TensorStorage.layout();
        TensorStorage.TensorMeta storage m = l.meta[tensorId];

        require(l.exists[tensorId], "tensor missing");
        require(m.owner == msg.sender, "not owner");
        require(!TensorPayload.hasPayload(l, tensorId), "payload exists");
        require(!TensorPayload.hasPackedU8(l, tensorId), "packed exists");

        uint256 expected = m.size * 32;
        require(m.size == 0 || expected / 32 == m.size, "payload size overflow");
        require(payload.length == expected, "payload size mismatch");

        uint256 total = payload.length;
        uint256 chunkSize = TensorPayload.chunkBytes();
        uint256 offset = 0;

        while (offset < total) {
            uint256 len = total - offset;
            if (len > chunkSize) {
                len = chunkSize;
            }

            bytes memory chunk = _sliceCalldata(payload, offset, len);
            address ptr = address(new TensorSSTORE2Data(chunk));
            l.payloadChunks[tensorId].push(ptr);
            offset += len;
        }

        emit TensorPayloadWritten(
            tensorId,
            total,
            l.payloadChunks[tensorId].length
        );
    }

    function readTensor(bytes32 tensorId) external view returns (bytes memory) {
        TensorStorage.Layout storage l = TensorStorage.layout();
        return TensorPayload.readPayload(l, tensorId);
    }

    function readAt(
        bytes32 tensorId,
        uint256 offset,
        uint256 length
    ) external view returns (bytes memory) {
        TensorStorage.Layout storage l = TensorStorage.layout();
        return TensorPayload.readPayloadAt(l, tensorId, offset, length);
    }

    function payloadChunkCount(bytes32 tensorId)
        external
        view
        returns (uint256)
    {
        return TensorStorage.layout().payloadChunks[tensorId].length;
    }

    function payloadChunkAt(bytes32 tensorId, uint256 index)
        external
        view
        returns (address)
    {
        return TensorStorage.layout().payloadChunks[tensorId][index];
    }

    function payloadChunkBytes() external pure returns (uint256) {
        return TensorPayload.chunkBytes();
    }

    function _sliceCalldata(
        bytes calldata data,
        uint256 start,
        uint256 length
    ) private pure returns (bytes memory out) {
        out = new bytes(length);
        assembly {
            calldatacopy(add(out, 0x20), add(data.offset, start), length)
        }
    }
}

/// @notice Tiny data contract that returns its payload as runtime bytecode.
contract TensorSSTORE2Data {
    constructor(bytes memory data) {
        assembly {
            return(add(data, 0x20), mload(data))
        }
    }
}
