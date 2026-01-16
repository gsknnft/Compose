// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";

import {TensorHarness} from "src/diamondTensors/mocks/TensorHarness.sol";
import {TensorStorage} from "src/diamondTensors/TensorStorage.sol";
import {SeedUtils} from "src/diamondTensors/SeedUtils.sol";

contract TensorBackendRegressionTest is Test {
    TensorHarness internal tensor;

    bytes32 internal constant SEED_MULTI_CHUNK = bytes32(hex"aaaa00000000000000000000000000000000000000000000000000000000aa01");
    bytes32 internal constant SEED_MULTI_WORD = bytes32(hex"bbbb00000000000000000000000000000000000000000000000000000000bb01");
    bytes32 internal constant SEED_DESTROY = bytes32(hex"cccc00000000000000000000000000000000000000000000000000000000cc01");
    bytes32 internal constant SEED_EMPTY = bytes32(hex"dddd00000000000000000000000000000000000000000000000000000000dd01");

    function setUp() public {
        tensor = new TensorHarness();
    }

    function testPayloadWritesAcrossMultipleChunks() public {
        uint256 size = 800; // > 768 elements to span two 24_576-byte chunks
        uint256[] memory shape = _shape1(size);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_MULTI_CHUNK, 1);

        int256[] memory values = new int256[](size);
        for (uint256 i; i < size; i++) {
            values[i] = int256(i + 1);
        }

        bytes memory payload = _encodeInt256Array(values);
        tensor.writeTensor(tensorId, payload);

        // spot-check boundaries around the first/second chunk split
        assertEq(tensor.get(tensorId, 0), 1);
        assertEq(tensor.get(tensorId, 767), 768);
        assertEq(tensor.get(tensorId, 768), 769);
        assertEq(tensor.get(tensorId, 799), 800);

        // freeze twice to ensure deterministic capsule after payload write
        bytes32 first = tensor.freezeTensor(tensorId);
        bytes32 second = tensor.freezeTensor(tensorId);
        assertEq(first, second);

        // two chunks expected: 800 * 32 = 25,600 bytes (> 24,576)
        assertEq(tensor.payloadChunkCount(tensorId), 2);
    }

    function testPackedU8ReadsBeyondFirstWord() public {
        uint256 size = 40; // spans into word index 1 (32-byte words)
        uint256[] memory shape = _shape1(size);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_MULTI_WORD, 1);

        uint8[] memory packed = new uint8[](size);
        for (uint256 i; i < size; i++) {
            packed[i] = uint8(i + 1);
        }

        tensor.writePackedU8(tensorId, _toBytes(packed));

        // word 0 indices
        assertEq(tensor.get(tensorId, 0), 1);
        assertEq(tensor.get(tensorId, 31), 32);
        // word 1 indices
        assertEq(tensor.get(tensorId, 32), 33);
        assertEq(tensor.get(tensorId, 39), 40);

        TensorStorage.TensorKey[] memory keys = _keys(tensorId, size);
        int256[] memory got = tensor.batchGet(keys);
        assertEq(got[0], 1);
        assertEq(got[31], 32);
        assertEq(got[32], 33);
        assertEq(got[39], 40);
    }

    function testDestroyAndRecreateAllowsSameId() public {
        uint256[] memory shape = _shape1(4);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_DESTROY, 1);

        // non-owner cannot destroy
        vm.prank(address(0xBEEF));
        vm.expectRevert("not owner");
        tensor.destroyTensor(tensorId);

        // owner destroys
        tensor.destroyTensor(tensorId);

        // recreate with same seed/nonce yields identical id and succeeds
        bytes32 recreated = tensor.createTensor(1, shape, SEED_DESTROY, 1);
        assertEq(recreated, tensorId);
    }

    function testFreezeZeroInitializedTensor() public {
        uint256[] memory shape = _shape1(1);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_EMPTY, 1);

        bytes32 first = tensor.freezeTensor(tensorId);
        bytes32 second = tensor.freezeTensor(tensorId);
        assertEq(first, second);
    }

    function testCreateRejectsRankShapeMismatch() public {
        uint256[] memory shape = _shape1(3);
        vm.expectRevert(bytes("rank mismatch"));
        tensor.createTensor(2, shape, SEED_MULTI_CHUNK, 2);
    }

    function testAddRevertsOnShapeMismatch() public {
        uint256[] memory aShape = _shape1(3);
        uint256[] memory bShape = _shape1(4);
        bytes32 a = tensor.createTensor(1, aShape, SEED_MULTI_CHUNK, 3);
        bytes32 b = tensor.createTensor(1, bShape, SEED_MULTI_CHUNK, 4);

        vm.expectRevert(bytes("shape mismatch"));
        tensor.add(a, b, SEED_MULTI_CHUNK);
    }

    function testDotRevertsWhenNot1D() public {
        uint256[] memory shape = _shape2(2, 2);
        bytes32 a = tensor.createTensor(2, shape, SEED_MULTI_CHUNK, 5);
        bytes32 b = tensor.createTensor(2, shape, SEED_MULTI_CHUNK, 6);

        vm.expectRevert(bytes("not 1D"));
        tensor.dot(a, b, SEED_MULTI_CHUNK);
    }

    function testWriteTensorSizeMismatchReverts() public {
        uint256[] memory shape = _shape1(2);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_MULTI_CHUNK, 7);

        // wrong length: needs 2 * 32 = 64 bytes
        bytes memory badPayload = hex"01";
        vm.expectRevert(bytes("payload size mismatch"));
        tensor.writeTensor(tensorId, badPayload);
    }

    function testWritePackedU8SizeMismatchReverts() public {
        uint256[] memory shape = _shape1(3);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_MULTI_WORD, 7);

        uint8[] memory bad = new uint8[](2); // needs length 3
        vm.expectRevert(bytes("payload size mismatch"));
        tensor.writePackedU8(tensorId, _toBytes(bad));
    }

    function testWriteAfterPayloadImmutableReverts() public {
        uint256[] memory shape = _shape1(2);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_MULTI_CHUNK, 8);

        int256[] memory vals = new int256[](2);
        vals[0] = 1;
        vals[1] = 2;
        tensor.writeTensor(tensorId, _encodeInt256Array(vals));

        vm.expectRevert(bytes("payload immutable"));
        tensor.set(tensorId, 0, 9);

        TensorStorage.TensorKey[] memory keys = _keys(tensorId, 2);
        int256[] memory newVals = new int256[](2);
        newVals[0] = 3;
        newVals[1] = 4;
        vm.expectRevert(bytes("payload immutable"));
        tensor.batchSet(keys, newVals);
    }

    function testWriteAfterPackedImmutableReverts() public {
        uint256[] memory shape = _shape1(2);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_MULTI_WORD, 8);

        uint8[] memory packed = new uint8[](2);
        packed[0] = 7;
        packed[1] = 8;
        tensor.writePackedU8(tensorId, _toBytes(packed));

        vm.expectRevert(bytes("packed immutable"));
        tensor.set(tensorId, 0, 1);

        TensorStorage.TensorKey[] memory keys = _keys(tensorId, 2);
        int256[] memory vals = new int256[](2);
        vals[0] = 1;
        vals[1] = 2;
        vm.expectRevert(bytes("packed immutable"));
        tensor.batchSet(keys, vals);
    }

    function testBatchSetLengthMismatchReverts() public {
        uint256[] memory shape = _shape1(2);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_DESTROY, 2);

        TensorStorage.TensorKey[] memory keys = _keys(tensorId, 2);
        int256[] memory vals = new int256[](1);
        vals[0] = 1;

        vm.expectRevert(bytes("length mismatch"));
        tensor.batchSet(keys, vals);
    }

    function testReadPackedMissingReverts() public {
        uint256[] memory shape = _shape1(1);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_DESTROY, 3);

        vm.expectRevert(bytes("packed missing"));
        tensor.readPackedU8(tensorId);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _shape1(uint256 a) internal pure returns (uint256[] memory s) {
        s = new uint256[](1);
        s[0] = a;
    }

    function _shape2(uint256 a, uint256 b) internal pure returns (uint256[] memory s) {
        s = new uint256[](2);
        s[0] = a;
        s[1] = b;
    }

    function _keys(bytes32 tensorId, uint256 count) internal pure returns (TensorStorage.TensorKey[] memory keys) {
        keys = new TensorStorage.TensorKey[](count);
        for (uint256 i; i < count; i++) {
            keys[i] = TensorStorage.TensorKey({id: tensorId, flatIndex: i});
        }
    }

    function _encodeInt256Array(int256[] memory vals) internal pure returns (bytes memory out) {
        out = new bytes(vals.length * 32);
        assembly ("memory-safe") {
            let ptr := add(out, 0x20)
            for { let i := 0 } lt(i, mload(vals)) { i := add(i, 1) } {
                mstore(add(ptr, mul(i, 32)), mload(add(add(vals, 0x20), mul(i, 32))))
            }
        }
    }

    function _toBytes(uint8[] memory vals) internal pure returns (bytes memory out) {
        out = new bytes(vals.length);
        for (uint256 i; i < vals.length; i++) {
            out[i] = bytes1(vals[i]);
        }
    }
}