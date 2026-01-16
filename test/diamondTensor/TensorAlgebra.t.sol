// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";

import {TensorHarness} from "src/diamondTensors/mocks/TensorHarness.sol";

contract TensorAlgebraTest is Test {
    TensorHarness internal tensor;

    bytes32 internal tensorAId;
    bytes32 internal tensorBId;

    bytes32 internal constant SEED_A = bytes32(hex"aaaa000000000000000000000000000000000000000000000000000000000001");
    bytes32 internal constant SEED_B = bytes32(hex"aaaa000000000000000000000000000000000000000000000000000000000002");
    bytes32 internal constant SEED_ADD = bytes32(hex"bbbb000000000000000000000000000000000000000000000000000000000001");
    bytes32 internal constant SEED_ADD_BA = bytes32(hex"bbbb000000000000000000000000000000000000000000000000000000000002");
    bytes32 internal constant SEED_SCALE_ADD = bytes32(hex"cccc000000000000000000000000000000000000000000000000000000000001");
    bytes32 internal constant SEED_SCALE_A = bytes32(hex"cccc000000000000000000000000000000000000000000000000000000000002");
    bytes32 internal constant SEED_SCALE_B = bytes32(hex"cccc000000000000000000000000000000000000000000000000000000000003");
    bytes32 internal constant SEED_SCALE_ID = bytes32(hex"dddd000000000000000000000000000000000000000000000000000000000001");

    int256 internal constant VALUE_LIMIT = 1e18;
    int256 internal constant SCALAR_LIMIT = 1e9;

    function setUp() public {
        tensor = new TensorHarness();

        uint256[] memory shape2x2 = _shape(2, 2);
        tensorAId = tensor.createTensor(2, shape2x2, SEED_A, 1);
        tensorBId = tensor.createTensor(2, shape2x2, SEED_B, 1);
    }

    function testAddCommutative(int256[4] memory aVals, int256[4] memory bVals) public {
        _assumeWithin(aVals, VALUE_LIMIT);
        _assumeWithin(bVals, VALUE_LIMIT);
        int256[4] memory a = aVals;
        int256[4] memory b = bVals;

        _setFlat(tensorAId, a);
        _setFlat(tensorBId, b);

        bytes32 outAB = tensor.add(tensorAId, tensorBId, SEED_ADD);
        bytes32 outBA = tensor.add(tensorBId, tensorAId, SEED_ADD_BA);

        int256[] memory ab = _readFlat(outAB, 4);
        int256[] memory ba = _readFlat(outBA, 4);
        assertEq(ab, ba);
    }

    function testScaleDistributive(int256[4] memory aVals, int256[4] memory bVals, int256 scalar) public {
        _assumeWithin(aVals, VALUE_LIMIT);
        _assumeWithin(bVals, VALUE_LIMIT);
        vm.assume(scalar <= SCALAR_LIMIT && scalar >= -SCALAR_LIMIT);

        int256[4] memory a = aVals;
        int256[4] memory b = bVals;
        int256 s = scalar;

        _setFlat(tensorAId, a);
        _setFlat(tensorBId, b);

        bytes32 outAdd = tensor.add(tensorAId, tensorBId, SEED_ADD);
        bytes32 left = tensor.scale(outAdd, s, SEED_SCALE_ADD);

        bytes32 scaledA = tensor.scale(tensorAId, s, SEED_SCALE_A);
        bytes32 scaledB = tensor.scale(tensorBId, s, SEED_SCALE_B);
        bytes32 right = tensor.add(scaledA, scaledB, SEED_ADD_BA);

        int256[] memory leftVals = _readFlat(left, 4);
        int256[] memory rightVals = _readFlat(right, 4);
        assertEq(leftVals, rightVals);
    }

    function testScaleIdentity(int256[4] memory aVals) public {
        _assumeWithin(aVals, VALUE_LIMIT);

        _setFlat(tensorAId, aVals);

        bytes32 scaled = tensor.scale(tensorAId, 1, SEED_SCALE_ID);
        int256[] memory original = _readFlat(tensorAId, 4);
        int256[] memory scaledVals = _readFlat(scaled, 4);

        assertEq(scaledVals, original);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _shape(uint256 a, uint256 b) internal pure returns (uint256[] memory s) {
        s = new uint256[](2);
        s[0] = a;
        s[1] = b;
    }

    function _setFlat(bytes32 tensorId, int256[4] memory vals) internal {
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

    function _assumeWithin(int256[4] memory vals, int256 limit) internal pure {
        for (uint256 i; i < vals.length; i++) {
            vm.assume(vals[i] <= limit && vals[i] >= -limit);
        }
    }
}
