// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorManagerFacet} from "../TensorManagerFacet.sol";
import {TensorReadFacet} from "../TensorReadFacet.sol";
import {TensorWriteFacet} from "../TensorWriteFacet.sol";
import {TensorBatchFacet} from "../TensorBatchFacet.sol";
import {TensorMathFacet} from "../TensorMathFacet.sol";
import {TensorSSTORE2Facet} from "../backends/TensorSSTORE2Facet.sol";
import {CapsuleFacet} from "../components/CapsuleFacet.sol";
import {TensorPackedU8Facet} from "../backends/TensorPackedU8Facet.sol";

/// @notice Test-only harness that composes core facets into one contract.
contract TensorHarness is
    TensorManagerFacet,
    TensorReadFacet,
    TensorWriteFacet,
    TensorBatchFacet,
    TensorMathFacet,
    TensorSSTORE2Facet,
    CapsuleFacet,
    TensorPackedU8Facet
{}
