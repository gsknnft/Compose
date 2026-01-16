// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

abstract contract Utils {
    Vm internal constant _vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant NUM_LOUPE_SELECTORS = 4;
    uint256 internal constant NUM_FACETS = 32;
    uint256 internal constant SELECTORS_PER_FACET = 16;
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");
    bytes4 internal constant SELECTOR_FACETS = bytes4(keccak256("facets()"));
    bytes4 internal constant SELECTOR_FACET_FUNCTION_SELECTORS =
        bytes4(keccak256("facetFunctionSelectors(address)"));
    bytes4 internal constant SELECTOR_FACET_ADDRESSES = bytes4(keccak256("facetAddresses()"));
    bytes4 internal constant SELECTOR_FACET_ADDRESS = bytes4(keccak256("facetAddress(bytes4)"));

    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    function getBlockTimestamp() internal view returns (uint40) {
        return uint40(_vm.getBlockTimestamp());
    }

    function setMsgSender(address msgSender) internal {
        _vm.stopPrank();
        _vm.startPrank(msgSender);

        _vm.deal(msgSender, 1 ether); // Deal ETH to new caller.
    }

    /*//////////////////////////////////////////////////////////////
                             DIAMOND BUILD
    //////////////////////////////////////////////////////////////*/

    function _facetAndPositionsSlot(bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(selector, DIAMOND_STORAGE_POSITION));
    }

    function _packFacetAndPosition(address facet, uint16 position) internal pure returns (bytes32) {
        return bytes32((uint256(uint160(facet))) | (uint256(position) << 160));
    }

    function _storeFacetAndPosition(address account, bytes4 selector, address facet, uint16 position) internal {
        _vm.store(account, _facetAndPositionsSlot(selector), _packFacetAndPosition(facet, position));
    }

    function _selectorsLengthSlot() internal pure returns (bytes32) {
        return bytes32(uint256(DIAMOND_STORAGE_POSITION) + 1);
    }

    function _selectorsDataBase() internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(DIAMOND_STORAGE_POSITION) + 1));
    }

    function _storeSelectorAtIndex(address account, bytes4 selector, uint256 index) internal {
        bytes32 base = _selectorsDataBase();
        uint256 packedWordIndex = index / 8;
        uint256 laneIndex = index % 8;
        bytes32 packedWordSlot = bytes32(uint256(base) + packedWordIndex);

        bytes32 oldPackedWord = _vm.load(account, packedWordSlot);

        uint256 laneShiftBits = laneIndex * 32;
        uint256 clearLaneMask = ~(uint256(0xffffffff) << laneShiftBits);
        uint256 laneInsertBits = (uint256(uint32(selector)) << laneShiftBits);
        uint256 newPackedWord = (uint256(oldPackedWord) & clearLaneMask) | laneInsertBits;

        _vm.store(account, packedWordSlot, bytes32(newPackedWord));
    }

    function _buildDiamond(address account, uint256 nFacets, uint256 perFacet) internal {
        uint256 total = nFacets * perFacet + NUM_LOUPE_SELECTORS;
        _vm.store(account, _selectorsLengthSlot(), bytes32(total));

        uint256 globalIndex = NUM_LOUPE_SELECTORS;
        for (uint256 f; f < nFacets; f++) {
            address facet = _facetAddr(f);
            for (uint16 j; j < perFacet; j++) {
                bytes4 selector = _selectorFor(f, j);
                _storeSelectorAtIndex(account, selector, globalIndex);
                _storeFacetAndPosition(account, selector, facet, j);
                unchecked {
                    ++globalIndex;
                }
            }
        }
    }

    function _facetAddr(uint256 f) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked("facet_", f)))));
    }

    function _selectorFor(uint256 f, uint16 j) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked(uint256(f), uint256(j))));
    }
}
