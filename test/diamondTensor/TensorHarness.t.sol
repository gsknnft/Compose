// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";

import {TensorHarness} from "src/diamondTensors/mocks/TensorHarness.sol";
import {TensorStorage} from "src/diamondTensors/TensorStorage.sol";

contract TensorHarnessTest is Test {
    TensorHarness internal tensor;

    bytes32 internal tensorAId;
    bytes32 internal tensorBId;
    bytes32 internal tensorCId;
    bytes32 internal tensorDId;
    bytes32 internal tensorPayloadId;
    bytes32 internal tensorPackedId;

    bytes32 internal constant SEED_A = bytes32(hex"1111111111111111111111111111111111111111111111111111111111111111");
    bytes32 internal constant SEED_B = bytes32(hex"2222222222222222222222222222222222222222222222222222222222222222");
    bytes32 internal constant SEED_ADD = bytes32(hex"3333333333333333333333333333333333333333333333333333333333333333");
    bytes32 internal constant SEED_SCALE = bytes32(hex"4444444444444444444444444444444444444444444444444444444444444444");
    bytes32 internal constant SEED_C = bytes32(hex"5555555555555555555555555555555555555555555555555555555555555555");
    bytes32 internal constant SEED_D = bytes32(hex"6666666666666666666666666666666666666666666666666666666666666666");
    bytes32 internal constant SEED_DOT = bytes32(hex"7777777777777777777777777777777777777777777777777777777777777777");
    bytes32 internal constant SEED_PAYLOAD = bytes32(hex"8888888888888888888888888888888888888888888888888888888888888888");
    bytes32 internal constant SEED_PACKED = bytes32(hex"9999999999999999999999999999999999999999999999999999999999999999");

    function setUp() public {
        tensor = new TensorHarness();

        uint256[] memory shape2x2 = _shape(2, 2);
        uint256[] memory shape3 = _shape(3);

        tensorAId = tensor.createTensor(2, shape2x2, SEED_A, 1);
        tensorBId = tensor.createTensor(2, shape2x2, SEED_B, 1);

        _setFlat(tensorAId, _ints4(1, 2, 3, 4));
        _setFlat(tensorBId, _ints4(4, 3, 2, 1));

        tensorCId = tensor.createTensor(1, shape3, SEED_C, 1);
        tensorDId = tensor.createTensor(1, shape3, SEED_D, 1);

        _setFlat(tensorCId, _ints3(1, 2, 3));
        _setFlat(tensorDId, _ints3(4, 5, 6));
    }

    function testAddWritesExpectedValues() public {
        bytes32 outId = tensor.add(tensorAId, tensorBId, SEED_ADD);
        int256[] memory got = _readFlat(outId, 4);
        assertEq(got[0], 5);
        assertEq(got[1], 5);
        assertEq(got[2], 5);
        assertEq(got[3], 5);
    }

    function testScaleWritesExpectedValues() public {
        bytes32 outId = tensor.scale(tensorAId, 3, SEED_SCALE);
        int256[] memory got = _readFlat(outId, 4);
        assertEq(got[0], 3);
        assertEq(got[1], 6);
        assertEq(got[2], 9);
        assertEq(got[3], 12);
    }

    function testDotWritesExpectedScalar() public {
        bytes32 outId = tensor.dot(tensorCId, tensorDId, SEED_DOT);
        assertEq(tensor.get(outId, 0), 32);
    }

    function testPayloadBackendMatchesSlotReadsAndCapsuleHash() public {
        uint256[] memory shape2x2 = _shape(2, 2);
        tensorPayloadId = tensor.createTensor(2, shape2x2, SEED_PAYLOAD, 1);

        int256[] memory values = _ints4(1, 2, 3, 4);
        TensorStorage.TensorKey[] memory keys = _keys(tensorPayloadId, values.length);
        tensor.batchSet(keys, values);
        bytes32 rootSlot = tensor.freezeTensor(tensorPayloadId);

        bytes memory payload = _encodeInt256Array(values);
        tensor.writeTensor(tensorPayloadId, payload);

        int256[] memory got = _readFlat(tensorPayloadId, values.length);
        assertEq(got, values);

        int256[] memory gotBatch = tensor.batchGet(keys);
        assertEq(gotBatch, values);

        bytes32 rootPayload = tensor.freezeTensor(tensorPayloadId);
        assertEq(rootPayload, rootSlot);
    }

    function testPackedU8BackendOverridesSlotValues() public {
        uint256[] memory shape2x2 = _shape(2, 2);
        tensorPackedId = tensor.createTensor(2, shape2x2, SEED_PACKED, 1);

        int256[] memory slotValues = _ints4(1, 2, 3, 4);
        TensorStorage.TensorKey[] memory keys = _keys(tensorPackedId, slotValues.length);
        tensor.batchSet(keys, slotValues);
        bytes32 rootSlot = tensor.freezeTensor(tensorPackedId);

        uint8[] memory packed = new uint8[](4);
        packed[0] = 9;
        packed[1] = 8;
        packed[2] = 7;
        packed[3] = 6;

        tensor.writePackedU8(tensorPackedId, _toBytes(packed));

        int256[] memory got = _readFlat(tensorPackedId, packed.length);
        assertEq(got[0], 9);
        assertEq(got[1], 8);
        assertEq(got[2], 7);
        assertEq(got[3], 6);

        int256[] memory gotBatch = tensor.batchGet(keys);
        assertEq(gotBatch[0], 9);
        assertEq(gotBatch[1], 8);
        assertEq(gotBatch[2], 7);
        assertEq(gotBatch[3], 6);

        bytes32 rootPacked = tensor.freezeTensor(tensorPackedId);
        assertTrue(rootPacked != rootSlot);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _shape(uint256 a) internal pure returns (uint256[] memory s) {
        s = new uint256[](1);
        s[0] = a;
    }

    function _shape(uint256 a, uint256 b) internal pure returns (uint256[] memory s) {
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

    function _ints4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (int256[] memory out) {
        out = new int256[](4);
        out[0] = int256(a);
        out[1] = int256(b);
        out[2] = int256(c);
        out[3] = int256(d);
    }

    function _ints3(uint256 a, uint256 b, uint256 c) internal pure returns (int256[] memory out) {
        out = new int256[](3);
        out[0] = int256(a);
        out[1] = int256(b);
        out[2] = int256(c);
    }

    function _setFlat(bytes32 tensorId, int256[] memory vals) internal {
        for (uint256 i; i < vals.length; i++) {
            tensor.set(tensorId, i, vals[i]);
        }
    }

    function _readFlat(bytes32 tensorId, uint256 count) internal view returns (int256[] memory out) {
        out = new int256[](count);
        for (uint256 i; i < count; i++) {
            out[i] = tensor.get(tensorId, i);
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
