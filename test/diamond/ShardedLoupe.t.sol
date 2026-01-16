// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "forge-std/Test.sol";

import {DiamondUpgradeFacet} from "src/diamond/DiamondUpgradeFacet.sol";
import {ShardedDiamondLoupeFacet} from "src/diamond/ShardedDiamondLoupeFacet.sol";
import {PackedLoupeExtension} from "src/diamond/PackedLoupeExtension.sol";
import {InitShardedLoupe} from "src/diamond/InitShardedLoupe.sol";
import {LibDiamondShard} from "src/diamond/LibDiamondShard.sol";
import {LibShardedLoupe} from "src/diamond/LibShardedLoupe.sol";
import "src/diamond/DiamondMod.sol";

interface IDiamondUpgrade {
    function upgradeDiamond(
        DiamondUpgradeFacet.FacetFunctions[] calldata addFns,
        DiamondUpgradeFacet.FacetFunctions[] calldata replaceFns,
        bytes4[] calldata removeFns,
        address delegate,
        bytes calldata functionCall,
        bytes32 tag,
        bytes calldata metadata
    ) external;
}

contract MinimalDiamond {
    constructor(DiamondUpgradeFacet upgradeFacet, ShardedDiamondLoupeFacet loupeFacet, PackedLoupeExtension packedFacet, address owner) {
        _setOwner(owner);

        FacetFunctions[] memory facets = new FacetFunctions[](3);

        bytes4[] memory upgradeSelectors = new bytes4[](1);
        upgradeSelectors[0] = IDiamondUpgrade.upgradeDiamond.selector;
        facets[0] = FacetFunctions({facet: address(upgradeFacet), selectors: upgradeSelectors});

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = ShardedDiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[1] = ShardedDiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = ShardedDiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = ShardedDiamondLoupeFacet.facets.selector;
        facets[1] = FacetFunctions({facet: address(loupeFacet), selectors: loupeSelectors});

        bytes4[] memory packedSelectors = new bytes4[](3);
        packedSelectors[0] = PackedLoupeExtension.facetAddressesPacked.selector;
        packedSelectors[1] = PackedLoupeExtension.selectorsPacked.selector;
        packedSelectors[2] = PackedLoupeExtension.facetsPacked.selector;
        facets[2] = DiamondMod.FacetFunctions({facet: address(packedFacet), selectors: packedSelectors});

        DiamondMod.addFacets(facets);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}

    function _setOwner(address owner) internal {
        bytes32 position = keccak256("compose.owner");
        assembly {
            sstore(position, owner)
        }
    }
}

contract RebuildInit {
    function init() external {
        LibDiamondShard.rebuildDefaultShard();
    }
}

contract MockFacetA {
    function a() external pure returns (uint256) {
        return 1;
    }

    function b() external pure returns (uint256) {
        return 2;
    }
}

contract MockFacetB {
    function c() external pure returns (uint256) {
        return 3;
    }
}

contract ShardedLoupeTest is Test {
    MinimalDiamond internal diamond;
    DiamondUpgradeFacet internal upgradeFacet;
    ShardedDiamondLoupeFacet internal loupeFacet;
    PackedLoupeExtension internal packedFacet;
    InitShardedLoupe internal initFacet;
    RebuildInit internal rebuildInit;
    MockFacetA internal facetA;
    MockFacetB internal facetB;

    function setUp() public {
        upgradeFacet = new DiamondUpgradeFacet();
        loupeFacet = new ShardedDiamondLoupeFacet();
        packedFacet = new PackedLoupeExtension();
        initFacet = new InitShardedLoupe();
        rebuildInit = new RebuildInit();
        facetA = new MockFacetA();
        facetB = new MockFacetB();

        diamond = new MinimalDiamond(upgradeFacet, loupeFacet, packedFacet, address(this));

        _addFacet(address(facetA), _selectorsA());
    }

    function test_shardedLoupe_matches_traditional_after_enable() public {
        address loupeAddr = address(diamond);

        address[] memory beforeFacets = ShardedDiamondLoupeFacet(loupeAddr).facetAddresses();
        bytes4[] memory beforeSelectorsA = ShardedDiamondLoupeFacet(loupeAddr).facetFunctionSelectors(address(facetA));

        _enableShardedLoupe();

        address[] memory afterFacets = ShardedDiamondLoupeFacet(loupeAddr).facetAddresses();
        bytes4[] memory afterSelectorsA = ShardedDiamondLoupeFacet(loupeAddr).facetFunctionSelectors(address(facetA));

        _assertEqAddresses(beforeFacets, afterFacets);
        _assertEqSelectors(beforeSelectorsA, afterSelectorsA);

        bytes memory packedAddrs = PackedLoupeExtension(loupeAddr).facetAddressesPacked();
        _assertEqAddresses(afterFacets, _decodeAddresses(packedAddrs));

        bytes memory packedSelectorsA = PackedLoupeExtension(loupeAddr).selectorsPacked(address(facetA));
        _assertEqSelectors(afterSelectorsA, _decodeSelectors(packedSelectorsA));
    }

    function test_shardedLoupe_rebuild_after_new_facet() public {
        address loupeAddr = address(diamond);
        _enableShardedLoupe();

        _addFacetWithRebuild(address(facetB), _selectorsB());

        address[] memory facets = ShardedDiamondLoupeFacet(loupeAddr).facetAddresses();
        bytes4[] memory selectorsB = ShardedDiamondLoupeFacet(loupeAddr).facetFunctionSelectors(address(facetB));

        assertTrue(facets.length >= 2, "missing facets after rebuild");
        assertEq(selectorsB.length, 1, "facetB selectors mismatch");

        bytes memory packedAddrs = PackedLoupeExtension(loupeAddr).facetAddressesPacked();
        _assertContainsAddress(facets, address(facetB));
        _assertContainsAddress(_decodeAddresses(packedAddrs), address(facetB));

        bytes memory packedSelectorsB = PackedLoupeExtension(loupeAddr).selectorsPacked(address(facetB));
        _assertEqSelectors(selectorsB, _decodeSelectors(packedSelectorsB));
    }

    function _addFacet(address facet, bytes4[] memory selectors) internal {
        DiamondUpgradeFacet.FacetFunctions[] memory addFns = new DiamondUpgradeFacet.FacetFunctions[](1);
        addFns[0] = DiamondUpgradeFacet.FacetFunctions({facet: facet, selectors: selectors});
        IDiamondUpgrade(address(diamond)).upgradeDiamond(addFns, new DiamondUpgradeFacet.FacetFunctions[](0), new bytes4[](0), address(0), "", 0, "");
    }

    function _addFacetWithRebuild(address facet, bytes4[] memory selectors) internal {
        DiamondUpgradeFacet.FacetFunctions[] memory addFns = new DiamondUpgradeFacet.FacetFunctions[](1);
        addFns[0] = DiamondUpgradeFacet.FacetFunctions({facet: facet, selectors: selectors});
        IDiamondUpgrade(address(diamond)).upgradeDiamond(addFns, new DiamondUpgradeFacet.FacetFunctions[](0), new bytes4[](0), address(rebuildInit), abi.encodeWithSelector(RebuildInit.init.selector), 0, "");
    }

    function _enableShardedLoupe() internal {
        IDiamondUpgrade(address(diamond)).upgradeDiamond(new DiamondUpgradeFacet.FacetFunctions[](0), new DiamondUpgradeFacet.FacetFunctions[](0), new bytes4[](0), address(initFacet), abi.encodeWithSelector(InitShardedLoupe.init.selector), 0, "");
    }

    function _selectorsA() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](2);
        sels[0] = MockFacetA.a.selector;
        sels[1] = MockFacetA.b.selector;
    }

    function _selectorsB() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](1);
        sels[0] = MockFacetB.c.selector;
    }

    function _decodeAddresses(bytes memory packed) internal pure returns (address[] memory addrs) {
        if (packed.length == 0) {
            return addrs;
        }
        require(packed.length % 20 == 0, "bad address packing");
        uint256 count = packed.length / 20;
        addrs = new address[](count);
        for (uint256 i; i < count; i++) {
            uint256 offset = 20 * i;
            address addr;
            assembly {
                addr := shr(96, mload(add(add(packed, 0x20), offset)))
            }
            addrs[i] = addr;
        }
    }

    function _decodeSelectors(bytes memory packed) internal pure returns (bytes4[] memory sels) {
        if (packed.length == 0) {
            return sels;
        }
        require(packed.length % 4 == 0, "bad selector packing");
        uint256 count = packed.length / 4;
        sels = new bytes4[](count);
        for (uint256 i; i < count; i++) {
            uint256 offset = 4 * i;
            bytes4 sel;
            assembly {
                sel := mload(add(add(packed, 0x20), offset))
            }
            sels[i] = sel;
        }
    }

    function _assertEqAddresses(address[] memory a, address[] memory b) internal {
        assertEq(a.length, b.length, "address length mismatch");
        for (uint256 i; i < a.length; i++) {
            assertEq(a[i], b[i], "address mismatch");
        }
    }

    function _assertEqSelectors(bytes4[] memory a, bytes4[] memory b) internal {
        assertEq(a.length, b.length, "selector length mismatch");
        for (uint256 i; i < a.length; i++) {
            assertEq(a[i], b[i], "selector mismatch");
        }
    }

    function _assertContainsAddress(address[] memory arr, address target) internal {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] == target) {
                return;
            }
        }
        fail("address not found");
    }
}
