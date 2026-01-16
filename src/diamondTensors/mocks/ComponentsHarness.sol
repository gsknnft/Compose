// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorManagerFacet} from "../TensorManagerFacet.sol";
import {CapsuleRegistryFacet} from "../components/CapsuleRegistryFacet.sol";
import {NFTBindingFacet} from "../components/NFTBindingFacet.sol";

/// @notice Test-only harness that composes component facets into one contract.
contract ComponentsHarness is
    TensorManagerFacet,
    CapsuleRegistryFacet,
    NFTBindingFacet
{}
