// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal proof verifier mock used by CapsuleDiamondFacet tests.
contract MockProofVerifier {
    bool public result = true;

    function setResult(bool value) external {
        result = value;
    }

    function verify(
        bytes calldata,
        bytes32,
        bytes32
    ) external view returns (bool) {
        return result;
    }
}
