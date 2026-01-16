// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "./TensorStorage.sol";
import {SeedUtils} from "./SeedUtils.sol";

contract TensorManagerFacet {
    event TensorCreated(bytes32 indexed tensorId, address indexed owner);
    event TensorDestroyed(bytes32 indexed tensorId);

    function createTensor(
        uint8 rank,
        uint256[] calldata shape,
        bytes32 seed,
        uint64 nonce
    ) external returns (bytes32 tensorId) {
        TensorStorage.Layout storage l = TensorStorage.layout();

        require(rank == shape.length, "rank mismatch");

        tensorId = SeedUtils.tensorId(msg.sender, seed, nonce);
        require(!l.exists[tensorId], "exists");

        uint256 size = SeedUtils.computeSize(shape);

        l.exists[tensorId] = true;
        TensorStorage.TensorMeta storage m = l.meta[tensorId];
        m.id = tensorId;
        m.owner = msg.sender;
        m.rank = rank;
        m.size = size;
        m.createdAt = uint64(block.timestamp);
        m.flags = 0;
        m.reserved = 0;
        // copy shape from calldata into storage
        m.shape = new uint256[](shape.length);
        for (uint256 i = 0; i < shape.length; i++) {
            m.shape[i] = shape[i];
        }

        l.owned[msg.sender].push(tensorId);

        emit TensorCreated(tensorId, msg.sender);
    }

    function destroyTensor(bytes32 tensorId) external {
        TensorStorage.Layout storage l = TensorStorage.layout();
        require(l.exists[tensorId], "missing");
        require(l.meta[tensorId].owner == msg.sender, "not owner");

        delete l.meta[tensorId];
        delete l.exists[tensorId];
        delete l.payloadChunks[tensorId];
        delete l.packedU8[tensorId];
        delete l.packedU8Exists[tensorId];

        emit TensorDestroyed(tensorId);
    }
}
