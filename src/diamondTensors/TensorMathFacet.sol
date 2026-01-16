// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorStorage} from "./TensorStorage.sol";
import {SeedUtils} from "./SeedUtils.sol";
import {TensorPayload} from "./backends/TensorPayload.sol";

/// @title TensorMathFacet
/// @notice Deterministic math operations over tensors.
/// @dev All operations produce NEW tensors (functional style).
contract TensorMathFacet {
    event TensorComputed(
        bytes32 indexed inputA,
        bytes32 indexed inputB,
        bytes32 indexed output,
        string op
    );

    // ---------------------------------------------------------------------
    // Elementwise add
    // ---------------------------------------------------------------------

    function add(
        bytes32 a,
        bytes32 b,
        bytes32 seed
    ) external returns (bytes32 out) {
        TensorStorage.Layout storage l = TensorStorage.layout();

        TensorStorage.TensorMeta storage ma = l.meta[a];
        TensorStorage.TensorMeta storage mb = l.meta[b];

        require(ma.owner == msg.sender, "not owner A");
        require(mb.owner == msg.sender, "not owner B");
        require(l.exists[a], "missing A");
        require(l.exists[b], "missing B");
        require(ma.rank == mb.rank, "rank mismatch");
        require(ma.size == mb.size, "shape mismatch");

        uint64 nonce = ++l.nonces[msg.sender][seed];
        out = SeedUtils.tensorId(msg.sender, seed, nonce);

        // create output tensor metadata
        l.exists[out] = true;
        l.meta[out] = TensorStorage.TensorMeta({
            id: out,
            owner: msg.sender,
            rank: ma.rank,
            shape: ma.shape,
            size: ma.size,
            createdAt: uint64(block.timestamp),
            flags: 0,
            reserved: 0
        });

        l.owned[msg.sender].push(out);

        // compute
        for (uint256 i = 0; i < ma.size; i++) {
            l.data[out][i] =
                TensorPayload.readValue(l, a, i) +
                TensorPayload.readValue(l, b, i);
        }

        emit TensorComputed(a, b, out, "add");
    }

    // ---------------------------------------------------------------------
    // Scale (multiply tensor by scalar)
    // ---------------------------------------------------------------------

    function scale(
        bytes32 a,
        int256 scalar,
        bytes32 seed
    ) external returns (bytes32 out) {
        TensorStorage.Layout storage l = TensorStorage.layout();

        TensorStorage.TensorMeta storage ma = l.meta[a];
        require(ma.owner == msg.sender, "not owner");
        require(l.exists[a], "missing");

        uint64 nonce = ++l.nonces[msg.sender][seed];
        out = SeedUtils.tensorId(msg.sender, seed, nonce);

        l.exists[out] = true;
        l.meta[out] = TensorStorage.TensorMeta({
            id: out,
            owner: msg.sender,
            rank: ma.rank,
            shape: ma.shape,
            size: ma.size,
            createdAt: uint64(block.timestamp),
            flags: 0,
            reserved: 0
        });

        l.owned[msg.sender].push(out);

        for (uint256 i = 0; i < ma.size; i++) {
            l.data[out][i] = TensorPayload.readValue(l, a, i) * scalar;
        }

        emit TensorComputed(a, bytes32(0), out, "scale");
    }

    // ---------------------------------------------------------------------
    // Dot product (1D tensors only)
    // ---------------------------------------------------------------------

    function dot(
        bytes32 a,
        bytes32 b,
        bytes32 seed
    ) external returns (bytes32 out) {
        TensorStorage.Layout storage l = TensorStorage.layout();

        TensorStorage.TensorMeta storage ma = l.meta[a];
        TensorStorage.TensorMeta storage mb = l.meta[b];

        require(ma.owner == msg.sender, "not owner A");
        require(mb.owner == msg.sender, "not owner B");
        require(l.exists[a], "missing A");
        require(l.exists[b], "missing B");
        require(ma.rank == 1 && mb.rank == 1, "not 1D");
        require(ma.size == mb.size, "length mismatch");

        uint64 nonce = ++l.nonces[msg.sender][seed];
        out = SeedUtils.tensorId(msg.sender, seed, nonce);

        l.exists[out] = true;

        uint256[] memory shape = new uint256[](1);
        shape[0] = 1;

        TensorStorage.TensorMeta storage m = l.meta[out];
        m.id = out;
        m.owner = msg.sender;
        m.rank = 1;
        m.size = 1;
        m.createdAt = uint64(block.timestamp);
        m.flags = 0;
        m.reserved = 0;
        m.shape = shape;

        l.owned[msg.sender].push(out);

        int256 acc;
        for (uint256 i = 0; i < ma.size; i++) {
            acc += TensorPayload.readValue(l, a, i) * TensorPayload.readValue(l, b, i);
        }

        l.data[out][0] = acc;

        emit TensorComputed(a, b, out, "dot");
    }
}
