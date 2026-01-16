// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TensorManagerFacet} from "../diamondTensors/TensorManagerFacet.sol";
import {TensorReadFacet} from "../diamondTensors/TensorReadFacet.sol";
import {TensorWriteFacet} from "../diamondTensors/TensorWriteFacet.sol";
import {TensorBatchFacet} from "../diamondTensors/TensorBatchFacet.sol";
import {TensorMathFacet} from "../diamondTensors/TensorMathFacet.sol";
import {TensorSSTORE2Facet} from "../diamondTensors/backends/TensorSSTORE2Facet.sol";
import {CapsuleFacet} from "../diamondTensors/components/CapsuleFacet.sol";
import {TensorPackedU8Facet} from "../diamondTensors/backends/TensorPackedU8Facet.sol";

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
