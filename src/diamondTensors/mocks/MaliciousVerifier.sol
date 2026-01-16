// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Verifier mock that attempts reentrancy during verify.
contract MaliciousVerifier {
    address public reenterTarget;
    bytes public reenterData;
    bool public reenterEnabled;

    function setReenter(
        address target,
        bytes calldata data,
        bool enabled
    ) external {
        reenterTarget = target;
        reenterData = data;
        reenterEnabled = enabled;
    }

    function verify(
        bytes calldata,
        bytes32,
        bytes32
    ) external view returns (bool) {
        if (reenterEnabled && reenterTarget != address(0)) {
            (bool ok, ) = reenterTarget.staticcall(reenterData);
            require(!ok, "reentrancy succeeded");
        }
        return true;
    }
}
