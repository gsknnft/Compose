// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";

import {TensorHarness} from "src/diamondTensors/mocks/TensorHarness.sol";
import {TensorStorage} from "src/diamondTensors/TensorStorage.sol";

contract TensorMathGasTest is Test {
    uint256 internal constant CHUNK_SIZE = 256;

    TensorHarness internal tensor;

    bytes32 internal constant SEED_ADD_A = bytes32(hex"0101010101010101010101010101010101010101010101010101010101010101");
    bytes32 internal constant SEED_ADD_B = bytes32(hex"0202020202020202020202020202020202020202020202020202020202020202");
    bytes32 internal constant SEED_ADD_OUT = bytes32(hex"0303030303030303030303030303030303030303030303030303030303030303");

    bytes32 internal constant SEED_ADD_MID_A = bytes32(hex"2121212121212121212121212121212121212121212121212121212121212121");
    bytes32 internal constant SEED_ADD_MID_B = bytes32(hex"2222222222222222222222222222222222222222222222222222222222222222");
    bytes32 internal constant SEED_ADD_MID_OUT = bytes32(hex"2323232323232323232323232323232323232323232323232323232323232323");

    bytes32 internal constant SEED_SCALE = bytes32(hex"0404040404040404040404040404040404040404040404040404040404040404");

    bytes32 internal constant SEED_SCALE_MID = bytes32(hex"2424242424242424242424242424242424242424242424242424242424242424");

    bytes32 internal constant SEED_DOT_A = bytes32(hex"0505050505050505050505050505050505050505050505050505050505050505");
    bytes32 internal constant SEED_DOT_B = bytes32(hex"0606060606060606060606060606060606060606060606060606060606060606");
    bytes32 internal constant SEED_DOT_OUT = bytes32(hex"0707070707070707070707070707070707070707070707070707070707070707");

    bytes32 internal constant SEED_DOT_16_A = bytes32(hex"2525252525252525252525252525252525252525252525252525252525252525");
    bytes32 internal constant SEED_DOT_16_B = bytes32(hex"2626262626262626262626262626262626262626262626262626262626262626");
    bytes32 internal constant SEED_DOT_16_OUT = bytes32(hex"2727272727272727272727272727272727272727272727272727272727272727");

    bytes32 internal constant SEED_BATCH = bytes32(hex"0808080808080808080808080808080808080808080808080808080808080808");

    bytes32 internal constant SEED_BATCH_GET = bytes32(hex"0909090909090909090909090909090909090909090909090909090909090909");
    bytes32 internal constant SEED_BATCH_MID = bytes32(hex"2828282828282828282828282828282828282828282828282828282828282828");
    bytes32 internal constant SEED_BATCH_GET_MID = bytes32(hex"2929292929292929292929292929292929292929292929292929292929292929");
    bytes32 internal constant SEED_PAYLOAD = bytes32(hex"1010101010101010101010101010101010101010101010101010101010101010");
    bytes32 internal constant SEED_PACKED = bytes32(hex"1111111111111111111111111111111111111111111111111111111111111111");

    bytes32 internal constant SEED_BATCH_LARGE = bytes32(hex"1212121212121212121212121212121212121212121212121212121212121212");
    bytes32 internal constant SEED_BATCH_GET_LARGE = bytes32(hex"1313131313131313131313131313131313131313131313131313131313131313");
    bytes32 internal constant SEED_PAYLOAD_LARGE = bytes32(hex"1414141414141414141414141414141414141414141414141414141414141414");
    bytes32 internal constant SEED_PACKED_LARGE = bytes32(hex"1515151515151515151515151515151515151515151515151515151515151515");

    bytes32 internal constant SEED_BATCH_CHUNK = bytes32(hex"1616161616161616161616161616161616161616161616161616161616161616");
    bytes32 internal constant SEED_BATCH_CHUNK_GET = bytes32(hex"1717171717171717171717171717171717171717171717171717171717171717");

    bytes32 internal constant SEED_SPARSE_1 = bytes32(hex"1818181818181818181818181818181818181818181818181818181818181818");
    bytes32 internal constant SEED_SPARSE_5 = bytes32(hex"1919191919191919191919191919191919191919191919191919191919191919");
    bytes32 internal constant SEED_SPARSE_10 = bytes32(hex"1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a");

    bytes32 internal constant SEED_VEC3 = bytes32(hex"2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a");
    bytes32 internal constant SEED_VEC8 = bytes32(hex"2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b");
    bytes32 internal constant SEED_VEC16 = bytes32(hex"2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c2c");
    bytes32 internal constant SEED_VEC32 = bytes32(hex"2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d");

    function setUp() public {
        tensor = new TensorHarness();
    }

    function testGas_Add_8x8() public {
        uint256[] memory shape = _shape2(8, 8);
        uint256 count = _prod(shape);

        int256[] memory valsA = _fillValues(count, 1);
        int256[] memory valsB = _fillValues(count, 101);

        bytes32 a = _createAndFill(shape, SEED_ADD_A, valsA);
        bytes32 b = _createAndFill(shape, SEED_ADD_B, valsB);

        uint256 startGas = gasleft();
        bytes32 outId = tensor.add(a, b, SEED_ADD_OUT);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("add 8x8", gasUsed);

        assertEq(tensor.get(outId, 0), valsA[0] + valsB[0]);
    }

    function testGas_Scale_8x8() public {
        uint256[] memory shape = _shape2(8, 8);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 3);
        bytes32 a = _createAndFill(shape, SEED_SCALE, vals);

        uint256 startGas = gasleft();
        bytes32 outId = tensor.scale(a, 3, SEED_SCALE);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("scale 8x8", gasUsed);

        assertEq(tensor.get(outId, 0), vals[0] * 3);
    }

    function testGas_Add_4x4() public {
        uint256[] memory shape = _shape2(4, 4);
        uint256 count = _prod(shape);

        int256[] memory valsA = _fillValues(count, 5);
        int256[] memory valsB = _fillValues(count, 105);

        bytes32 a = _createAndFill(shape, SEED_ADD_MID_A, valsA);
        bytes32 b = _createAndFill(shape, SEED_ADD_MID_B, valsB);

        uint256 startGas = gasleft();
        bytes32 outId = tensor.add(a, b, SEED_ADD_MID_OUT);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("add 4x4", gasUsed);

        assertEq(tensor.get(outId, 0), valsA[0] + valsB[0]);
    }

    function testGas_Scale_4x4() public {
        uint256[] memory shape = _shape2(4, 4);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 13);
        bytes32 a = _createAndFill(shape, SEED_SCALE_MID, vals);

        uint256 startGas = gasleft();
        bytes32 outId = tensor.scale(a, 3, SEED_SCALE_MID);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("scale 4x4", gasUsed);

        assertEq(tensor.get(outId, 0), vals[0] * 3);
    }

    function testGas_Dot_32() public {
        uint256[] memory shape = _shape1(32);
        uint256 count = _prod(shape);

        int256[] memory valsA = _fillValues(count, 1);
        int256[] memory valsB = _fillValues(count, 2);

        bytes32 a = _createAndFill(shape, SEED_DOT_A, valsA);
        bytes32 b = _createAndFill(shape, SEED_DOT_B, valsB);

        uint256 startGas = gasleft();
        bytes32 outId = tensor.dot(a, b, SEED_DOT_OUT);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("dot 32", gasUsed);

        int256 expected = 0;
        for (uint256 i; i < count; i++) {
            expected += valsA[i] * valsB[i];
        }
        assertEq(tensor.get(outId, 0), expected);
    }

    function testGas_Dot_16() public {
        uint256[] memory shape = _shape1(16);
        uint256 count = _prod(shape);

        int256[] memory valsA = _fillValues(count, 2);
        int256[] memory valsB = _fillValues(count, 4);

        bytes32 a = _createAndFill(shape, SEED_DOT_16_A, valsA);
        bytes32 b = _createAndFill(shape, SEED_DOT_16_B, valsB);

        uint256 startGas = gasleft();
        bytes32 outId = tensor.dot(a, b, SEED_DOT_16_OUT);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("dot 16", gasUsed);

        int256 expected = 0;
        for (uint256 i; i < count; i++) {
            expected += valsA[i] * valsB[i];
        }
        assertEq(tensor.get(outId, 0), expected);
    }

    function testGas_BatchSet_8x8() public {
        uint256[] memory shape = _shape2(8, 8);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 11);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);

        uint256 startGas = gasleft();
        tensor.batchSet(keys, vals);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchSet 8x8", gasUsed, count);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function testGas_BatchSet_4x4() public {
        uint256[] memory shape = _shape2(4, 4);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 17);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_MID, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);

        uint256 startGas = gasleft();
        tensor.batchSet(keys, vals);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchSet 4x4", gasUsed, count);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function testGas_BatchGet_8x8() public {
        uint256[] memory shape = _shape2(8, 8);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 21);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_GET, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);
        tensor.batchSet(keys, vals);

        uint256 startGas = gasleft();
        int256[] memory got = tensor.batchGet(keys);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchGet 8x8", gasUsed, count);

        assertEq(got[0], vals[0]);
    }

    function testGas_BatchGet_4x4() public {
        uint256[] memory shape = _shape2(4, 4);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 27);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_GET_MID, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);
        tensor.batchSet(keys, vals);

        uint256 startGas = gasleft();
        int256[] memory got = tensor.batchGet(keys);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchGet 4x4", gasUsed, count);

        assertEq(got[0], vals[0]);
    }

    function testGas_BatchSet_32x32() public {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 51);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_LARGE, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);

        uint256 startGas = gasleft();
        tensor.batchSet(keys, vals);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchSet 32x32", gasUsed, count);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function testGas_BatchGet_32x32() public {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 61);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_GET_LARGE, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);
        tensor.batchSet(keys, vals);

        uint256 startGas = gasleft();
        int256[] memory got = tensor.batchGet(keys);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchGet 32x32", gasUsed, count);

        assertEq(got[0], vals[0]);
    }

    function testGas_BatchSet_32x32_Chunked64() public {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 91);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_CHUNK, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);

        uint256 startGas = gasleft();
        _chunkedBatchSet(keys, vals, CHUNK_SIZE);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchSet 32x32 chunked", gasUsed, count);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function testGas_BatchGet_32x32_Chunked64() public {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 101);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_BATCH_CHUNK_GET, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, count);
        tensor.batchSet(keys, vals);

        uint256 startGas = gasleft();
        int256[] memory got = _chunkedBatchGet(keys, CHUNK_SIZE);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchGet 32x32 chunked", gasUsed, count);

        assertEq(got[0], vals[0]);
    }

    function testGas_WriteTensor_8x8() public {
        uint256[] memory shape = _shape2(8, 8);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 31);
        bytes memory payload = _encodeInt256Array(vals);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_PAYLOAD, 1);

        uint256 startGas = gasleft();
        tensor.writeTensor(tensorId, payload);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("writeTensor 8x8", gasUsed);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function testGas_ReadTensor_8x8() public {
        uint256[] memory shape = _shape2(8, 8);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 41);
        bytes memory payload = _encodeInt256Array(vals);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_PAYLOAD, 2);
        tensor.writeTensor(tensorId, payload);

        uint256 startGas = gasleft();
        bytes memory raw = tensor.readTensor(tensorId);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("readTensor 8x8", gasUsed);

        int256[] memory decoded = _decodeInt256Array(raw);
        assertEq(decoded[0], vals[0]);
    }

    function testGas_WriteTensor_32x32() public {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 71);
        bytes memory payload = _encodeInt256Array(vals);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_PAYLOAD_LARGE, 1);

        uint256 startGas = gasleft();
        tensor.writeTensor(tensorId, payload);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("writeTensor 32x32", gasUsed);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function testGas_ReadTensor_32x32() public {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        int256[] memory vals = _fillValues(count, 81);
        bytes memory payload = _encodeInt256Array(vals);
        bytes32 tensorId = tensor.createTensor(2, shape, SEED_PAYLOAD_LARGE, 2);
        tensor.writeTensor(tensorId, payload);

        uint256 startGas = gasleft();
        bytes memory raw = tensor.readTensor(tensorId);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("readTensor 32x32", gasUsed);

        int256[] memory decoded = _decodeInt256Array(raw);
        assertEq(decoded[0], vals[0]);
    }

    function testGas_WritePackedU8_64() public {
        uint256[] memory shape = _shape1(64);
        uint256 count = _prod(shape);

        bytes memory payload = _fillU8Bytes(count, 5);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_PACKED, 1);

        uint256 startGas = gasleft();
        tensor.writePackedU8(tensorId, payload);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("writePackedU8 64", gasUsed);

        assertEq(tensor.get(tensorId, 0), int256(uint256(uint8(payload[0]))));
    }

    function testGas_ReadPackedU8_64() public {
        uint256[] memory shape = _shape1(64);
        uint256 count = _prod(shape);

        bytes memory payload = _fillU8Bytes(count, 7);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_PACKED, 2);
        tensor.writePackedU8(tensorId, payload);

        uint256 startGas = gasleft();
        bytes memory raw = tensor.readPackedU8(tensorId);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("readPackedU8 64", gasUsed);

        assertEq(uint8(raw[0]), uint8(payload[0]));
    }

    function testGas_WritePackedU8_256() public {
        uint256[] memory shape = _shape1(256);
        uint256 count = _prod(shape);

        bytes memory payload = _fillU8Bytes(count, 9);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_PACKED_LARGE, 1);

        uint256 startGas = gasleft();
        tensor.writePackedU8(tensorId, payload);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("writePackedU8 256", gasUsed);

        assertEq(tensor.get(tensorId, 0), int256(uint256(uint8(payload[0]))));
    }

    function testGas_ReadPackedU8_256() public {
        uint256[] memory shape = _shape1(256);
        uint256 count = _prod(shape);

        bytes memory payload = _fillU8Bytes(count, 11);
        bytes32 tensorId = tensor.createTensor(1, shape, SEED_PACKED_LARGE, 2);
        tensor.writePackedU8(tensorId, payload);

        uint256 startGas = gasleft();
        bytes memory raw = tensor.readPackedU8(tensorId);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("readPackedU8 256", gasUsed);

        assertEq(uint8(raw[0]), uint8(payload[0]));
    }

    function testGas_Vector_BatchSet_3() public {
        _gasVectorBatchSet(3, SEED_VEC3);
    }

    function testGas_Vector_BatchGet_3() public {
        _gasVectorBatchGet(3, SEED_VEC3);
    }

    function testGas_Vector_BatchSet_8() public {
        _gasVectorBatchSet(8, SEED_VEC8);
    }

    function testGas_Vector_BatchGet_8() public {
        _gasVectorBatchGet(8, SEED_VEC8);
    }

    function testGas_Vector_BatchSet_16() public {
        _gasVectorBatchSet(16, SEED_VEC16);
    }

    function testGas_Vector_BatchGet_16() public {
        _gasVectorBatchGet(16, SEED_VEC16);
    }

    function testGas_Vector_BatchSet_32() public {
        _gasVectorBatchSet(32, SEED_VEC32);
    }

    function testGas_Vector_BatchGet_32() public {
        _gasVectorBatchGet(32, SEED_VEC32);
    }

    function testGas_Vector_WriteTensor_32() public {
        _gasVectorPayload(32, SEED_VEC32);
    }

    function testGas_Vector_ReadTensor_32() public {
        _gasVectorPayloadRead(32, SEED_VEC32);
    }

    function testGas_Vector_WritePackedU8_32() public {
        _gasVectorPacked(32, SEED_VEC32);
    }

    function testGas_Vector_ReadPackedU8_32() public {
        _gasVectorPackedRead(32, SEED_VEC32);
    }

    function testGas_BatchSet_Sparse_1pct() public {
        _gasSparseBatchSet(1, 100, SEED_SPARSE_1);
    }

    function testGas_BatchSet_Sparse_5pct() public {
        _gasSparseBatchSet(5, 100, SEED_SPARSE_5);
    }

    function testGas_BatchSet_Sparse_10pct() public {
        _gasSparseBatchSet(10, 100, SEED_SPARSE_10);
    }

    function testGas_BatchGet_Sparse_1pct() public {
        _gasSparseBatchGet(1, 100, SEED_SPARSE_1);
    }

    function testGas_BatchGet_Sparse_5pct() public {
        _gasSparseBatchGet(5, 100, SEED_SPARSE_5);
    }

    function testGas_BatchGet_Sparse_10pct() public {
        _gasSparseBatchGet(10, 100, SEED_SPARSE_10);
    }

    function _createAndFill(
        uint256[] memory shape,
        bytes32 seed,
        int256[] memory values
    ) internal returns (bytes32 tensorId) {
        tensorId = tensor.createTensor(uint8(shape.length), shape, seed, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, values.length);
        tensor.batchSet(keys, values);
    }

    function _keys(bytes32 tensorId, uint256 count) internal pure returns (TensorStorage.TensorKey[] memory keys) {
        keys = new TensorStorage.TensorKey[](count);
        for (uint256 i; i < count; i++) {
            keys[i] = TensorStorage.TensorKey({id: tensorId, flatIndex: i});
        }
    }

    function _fillValues(uint256 count, uint256 start) internal pure returns (int256[] memory out) {
        out = new int256[](count);
        for (uint256 i; i < count; i++) {
            out[i] = int256(start + i);
        }
    }

    function _fillU8Bytes(uint256 count, uint8 start) internal pure returns (bytes memory out) {
        out = new bytes(count);
        for (uint256 i; i < count; i++) {
            uint256 val = uint256(start) + i;
            out[i] = bytes1(uint8(val));
        }
    }

    function _prod(uint256[] memory shape) internal pure returns (uint256 prod) {
        prod = 1;
        for (uint256 i; i < shape.length; i++) {
            prod *= shape[i];
        }
    }

    function _shape1(uint256 a) internal pure returns (uint256[] memory s) {
        s = new uint256[](1);
        s[0] = a;
    }

    function _shape2(uint256 a, uint256 b) internal pure returns (uint256[] memory s) {
        s = new uint256[](2);
        s[0] = a;
        s[1] = b;
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

    function _decodeInt256Array(bytes memory raw) internal pure returns (int256[] memory out) {
        uint256 count = raw.length / 32;
        out = new int256[](count);
        assembly ("memory-safe") {
            let ptr := add(raw, 0x20)
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                mstore(add(add(out, 0x20), mul(i, 32)), mload(add(ptr, mul(i, 32))))
            }
        }
    }

    function _chunkedBatchSet(
        TensorStorage.TensorKey[] memory keys,
        int256[] memory values,
        uint256 chunkSize
    ) internal {
        uint256 idx;
        while (idx < keys.length) {
            uint256 end = idx + chunkSize;
            if (end > keys.length) {
                end = keys.length;
            }
            TensorStorage.TensorKey[] memory sliceKeys = _sliceKeys(keys, idx, end);
            int256[] memory sliceVals = _sliceVals(values, idx, end);
            tensor.batchSet(sliceKeys, sliceVals);
            idx = end;
        }
    }

    function _chunkedBatchGet(TensorStorage.TensorKey[] memory keys, uint256 chunkSize)
        internal
        view
        returns (int256[] memory out)
    {
        out = new int256[](keys.length);
        uint256 idx;
        while (idx < keys.length) {
            uint256 end = idx + chunkSize;
            if (end > keys.length) {
                end = keys.length;
            }
            TensorStorage.TensorKey[] memory sliceKeys = _sliceKeys(keys, idx, end);
            int256[] memory sliceVals = tensor.batchGet(sliceKeys);
            for (uint256 i; i < sliceVals.length; i++) {
                out[idx + i] = sliceVals[i];
            }
            idx = end;
        }
    }

    function _sliceKeys(
        TensorStorage.TensorKey[] memory keys,
        uint256 start,
        uint256 end
    ) internal pure returns (TensorStorage.TensorKey[] memory slice) {
        slice = new TensorStorage.TensorKey[](end - start);
        for (uint256 i; i < slice.length; i++) {
            slice[i] = keys[start + i];
        }
    }

    function _sliceVals(
        int256[] memory vals,
        uint256 start,
        uint256 end
    ) internal pure returns (int256[] memory slice) {
        slice = new int256[](end - start);
        for (uint256 i; i < slice.length; i++) {
            slice[i] = vals[start + i];
        }
    }

    function _gasSparseBatchSet(
        uint256 numerator,
        uint256 denominator,
        bytes32 seed
    ) internal {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        uint256[] memory indices = _sparseIndices(count, numerator, denominator);
        TensorStorage.TensorKey[] memory keys = _keysFromIndices(seed, indices);
        int256[] memory vals = _fillValues(indices.length, 200 + numerator);

        uint256 startGas = gasleft();
        tensor.batchSet(keys, vals);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchSet sparse", gasUsed, keys.length);

        assertEq(tensor.get(keys[0].id, keys[0].flatIndex), vals[0]);
    }

    function _gasSparseBatchGet(
        uint256 numerator,
        uint256 denominator,
        bytes32 seed
    ) internal {
        uint256[] memory shape = _shape2(32, 32);
        uint256 count = _prod(shape);

        uint256[] memory indices = _sparseIndices(count, numerator, denominator);
        TensorStorage.TensorKey[] memory keys = _keysFromIndices(seed, indices);
        int256[] memory vals = _fillValues(indices.length, 300 + numerator);
        tensor.batchSet(keys, vals);

        uint256 startGas = gasleft();
        int256[] memory got = tensor.batchGet(keys);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("batchGet sparse", gasUsed, keys.length);

        assertEq(got[0], vals[0]);
    }

    function _sparseIndices(
        uint256 total,
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256[] memory out) {
        uint256 step = denominator / numerator;
        if (step == 0) {
            step = 1;
        }
        uint256 count;
        for (uint256 i; i < total; i += step) {
            count++;
        }
        out = new uint256[](count);
        uint256 idx;
        for (uint256 i; i < total; i += step) {
            out[idx] = i;
            idx++;
        }
    }

    function _logGasPerElem(string memory label, uint256 gasUsed, uint256 elems) internal {
        emit log_named_uint(label, gasUsed);
        if (elems != 0) {
            emit log_named_uint(string.concat(label, " gas/elem"), gasUsed / elems);
        }
    }

    function _keysFromIndices(bytes32 seed, uint256[] memory indices)
        internal
        returns (TensorStorage.TensorKey[] memory keys)
    {
        uint256[] memory shape = _shape2(32, 32);
        bytes32 tensorId = tensor.createTensor(2, shape, seed, 1);
        keys = new TensorStorage.TensorKey[](indices.length);
        for (uint256 i; i < indices.length; i++) {
            keys[i] = TensorStorage.TensorKey({id: tensorId, flatIndex: indices[i]});
        }
    }

    function _gasVectorBatchSet(uint256 length, bytes32 seed) internal {
        uint256[] memory shape = _shape1(length);
        int256[] memory vals = _fillValues(length, 400 + length);
        bytes32 tensorId = tensor.createTensor(1, shape, seed, 1);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, length);

        uint256 startGas = gasleft();
        tensor.batchSet(keys, vals);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("vec batchSet", gasUsed, length);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function _gasVectorBatchGet(uint256 length, bytes32 seed) internal {
        uint256[] memory shape = _shape1(length);
        int256[] memory vals = _fillValues(length, 500 + length);
        bytes32 tensorId = tensor.createTensor(1, shape, seed, 2);
        TensorStorage.TensorKey[] memory keys = _keys(tensorId, length);
        tensor.batchSet(keys, vals);

        uint256 startGas = gasleft();
        int256[] memory got = tensor.batchGet(keys);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("vec batchGet", gasUsed, length);

        assertEq(got[0], vals[0]);
    }

    function _gasVectorPayload(uint256 length, bytes32 seed) internal {
        uint256[] memory shape = _shape1(length);
        int256[] memory vals = _fillValues(length, 600 + length);
        bytes memory payload = _encodeInt256Array(vals);
        bytes32 tensorId = tensor.createTensor(1, shape, seed, 3);

        uint256 startGas = gasleft();
        tensor.writeTensor(tensorId, payload);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("vec writeTensor", gasUsed, length);

        assertEq(tensor.get(tensorId, 0), vals[0]);
    }

    function _gasVectorPayloadRead(uint256 length, bytes32 seed) internal {
        uint256[] memory shape = _shape1(length);
        int256[] memory vals = _fillValues(length, 700 + length);
        bytes memory payload = _encodeInt256Array(vals);
        bytes32 tensorId = tensor.createTensor(1, shape, seed, 4);
        tensor.writeTensor(tensorId, payload);

        uint256 startGas = gasleft();
        bytes memory raw = tensor.readTensor(tensorId);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("vec readTensor", gasUsed, length);

        int256[] memory decoded = _decodeInt256Array(raw);
        assertEq(decoded[0], vals[0]);
    }

    function _gasVectorPacked(uint256 length, bytes32 seed) internal {
        uint256[] memory shape = _shape1(length);
        bytes memory payload = _fillU8Bytes(length, 9 + uint8(length));
        bytes32 tensorId = tensor.createTensor(1, shape, seed, 5);

        uint256 startGas = gasleft();
        tensor.writePackedU8(tensorId, payload);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("vec writePackedU8", gasUsed, length);

        assertEq(tensor.get(tensorId, 0), int256(uint256(uint8(payload[0]))));
    }

    function _gasVectorPackedRead(uint256 length, bytes32 seed) internal {
        uint256[] memory shape = _shape1(length);
        bytes memory payload = _fillU8Bytes(length, 19 + uint8(length));
        bytes32 tensorId = tensor.createTensor(1, shape, seed, 6);
        tensor.writePackedU8(tensorId, payload);

        uint256 startGas = gasleft();
        bytes memory raw = tensor.readPackedU8(tensorId);
        uint256 gasUsed = startGas - gasleft();
        _logGasPerElem("vec readPackedU8", gasUsed, length);

        assertEq(uint8(raw[0]), uint8(payload[0]));
    }
}
