// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Utils} from "../utils/Utils.sol";
import {MinimalDiamond, FacetCut, FacetCutAction, DiamondArgs} from "./MinimalDiamond.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

abstract contract BaseBenchmark is Utils {
    MinimalDiamond internal diamond;
    address internal loupe;

    function setUp() public {
        diamond = new MinimalDiamond();
        loupe = _deployLoupe();

        // Initialize minimal diamond with DiamondLoupeFacet address and selectors.
        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = SELECTOR_FACET_ADDRESS;

        FacetCut[] memory dc = new FacetCut[](1);

        dc[0] = FacetCut({
            facetAddress: loupe, action: FacetCutAction.Add, functionSelectors: loupeSelectors
        });

        DiamondArgs memory args = DiamondArgs({init: address(0), initCalldata: ""});

        diamond.initialize(dc, args);

        _afterLoupeInstalled();

        // Initiatlise complex storage for minimal diamond
        _buildDiamond(address(diamond), NUM_FACETS, SELECTORS_PER_FACET);

        _afterDiamondPopulated();
    }

    function _deployLoupe() internal virtual returns (address);

    function _afterLoupeInstalled() internal virtual {}

    function _afterDiamondPopulated() internal virtual {}
}
