// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorManagerFacet} from "../diamondTensors/TensorManagerFacet.sol";
import {CapsuleRegistryFacet} from "../diamondTensors/components/CapsuleRegistryFacet.sol";
import {NFTBindingFacet} from "../diamondTensors/components/NFTBindingFacet.sol";

/// @notice Test-only harness that composes component facets into one contract.
contract ComponentsHarness is
    TensorManagerFacet,
    CapsuleRegistryFacet,
    NFTBindingFacet
{}
