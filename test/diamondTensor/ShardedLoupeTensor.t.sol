// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "forge-std/Test.sol";

import {DiamondUpgradeFacet} from "src/diamond/DiamondUpgradeFacet.sol";
import {ShardedDiamondLoupeFacet} from "src/diamond/ShardedDiamondLoupeFacet.sol";
import {PackedLoupeExtension} from "src/diamond/PackedLoupeExtension.sol";
import {InitShardedLoupe} from "src/diamond/InitShardedLoupe.sol";
import {LibDiamondShard} from "src/diamond/LibDiamondShard.sol";
import {DiamondMod} from "src/diamond/DiamondMod.sol";

import {TensorManagerFacet} from "src/diamondTensors/TensorManagerFacet.sol";
import {TensorReadFacet} from "src/diamondTensors/TensorReadFacet.sol";
import {TensorWriteFacet} from "src/diamondTensors/TensorWriteFacet.sol";
import {TensorSSTORE2Facet} from "src/diamondTensors/backends/TensorSSTORE2Facet.sol";

interface IDiamondUpgradeTensor {
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

contract MinimalDiamondTensor {
    constructor(DiamondUpgradeFacet upgradeFacet, ShardedDiamondLoupeFacet loupeFacet, PackedLoupeExtension packedFacet, address owner) {
        _setOwner(owner);

        DiamondMod.FacetFunctions[] memory facets = new DiamondMod.FacetFunctions[](3);

        bytes4[] memory upgradeSelectors = new bytes4[](1);
        upgradeSelectors[0] = IDiamondUpgradeTensor.upgradeDiamond.selector;
        facets[0] = DiamondMod.FacetFunctions({facet: address(upgradeFacet), selectors: upgradeSelectors});

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = ShardedDiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[1] = ShardedDiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = ShardedDiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = ShardedDiamondLoupeFacet.facets.selector;
        facets[1] = DiamondMod.FacetFunctions({facet: address(loupeFacet), selectors: loupeSelectors});

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

contract RebuildInitTensor {
    function init() external {
        LibDiamondShard.rebuildDefaultShard();
    }
}

contract ShardedLoupeTensorTest is Test {
    MinimalDiamondTensor internal diamond;
    DiamondUpgradeFacet internal upgradeFacet;
    ShardedDiamondLoupeFacet internal loupeFacet;
    PackedLoupeExtension internal packedFacet;
    InitShardedLoupe internal initFacet;
    RebuildInitTensor internal rebuildInit;

    TensorManagerFacet internal manager;
    TensorReadFacet internal reader;
    TensorWriteFacet internal writer;
    TensorSSTORE2Facet internal sstore2;

    function setUp() public {
        upgradeFacet = new DiamondUpgradeFacet();
        loupeFacet = new ShardedDiamondLoupeFacet();
        packedFacet = new PackedLoupeExtension();
        initFacet = new InitShardedLoupe();
        rebuildInit = new RebuildInitTensor();

        manager = new TensorManagerFacet();
        reader = new TensorReadFacet();
        writer = new TensorWriteFacet();
        sstore2 = new TensorSSTORE2Facet();

        diamond = new MinimalDiamondTensor(upgradeFacet, loupeFacet, packedFacet, address(this));

        _addFacet(address(manager), _selectorsManager());
        _addFacet(address(reader), _selectorsRead());
        _addFacet(address(writer), _selectorsWrite());
    }

    function test_tensorLoupe_packed_matches_after_enable() public {
        address loupeAddr = address(diamond);

        address[] memory beforeFacets = ShardedDiamondLoupeFacet(loupeAddr).facetAddresses();
        bytes4[] memory beforeSelectorsMgr = ShardedDiamondLoupeFacet(loupeAddr).facetFunctionSelectors(address(manager));

        _enableShardedLoupe();

        address[] memory afterFacets = ShardedDiamondLoupeFacet(loupeAddr).facetAddresses();
        bytes4[] memory afterSelectorsMgr = ShardedDiamondLoupeFacet(loupeAddr).facetFunctionSelectors(address(manager));

        _assertEqAddresses(beforeFacets, afterFacets);
        _assertEqSelectors(beforeSelectorsMgr, afterSelectorsMgr);

        _assertEqAddresses(afterFacets, _decodeAddresses(PackedLoupeExtension(loupeAddr).facetAddressesPacked()));
        _assertEqSelectors(afterSelectorsMgr, _decodeSelectors(PackedLoupeExtension(loupeAddr).selectorsPacked(address(manager))));
    }

    function test_tensorLoupe_rebuild_after_backend_added() public {
        address loupeAddr = address(diamond);
        _enableShardedLoupe();

        _addFacetWithRebuild(address(sstore2), _selectorsSSTORE2());

        address[] memory facets = ShardedDiamondLoupeFacet(loupeAddr).facetAddresses();
        bytes4[] memory selectors = ShardedDiamondLoupeFacet(loupeAddr).facetFunctionSelectors(address(sstore2));

        _assertContainsAddress(facets, address(sstore2));
        assertTrue(selectors.length >= 3, "unexpected backend selector count");

        _assertContainsAddress(_decodeAddresses(PackedLoupeExtension(loupeAddr).facetAddressesPacked()), address(sstore2));
        _assertEqSelectors(selectors, _decodeSelectors(PackedLoupeExtension(loupeAddr).selectorsPacked(address(sstore2))));
    }

    function _addFacet(address facet, bytes4[] memory selectors) internal {
        DiamondUpgradeFacet.FacetFunctions[] memory addFns = new DiamondUpgradeFacet.FacetFunctions[](1);
        addFns[0] = DiamondUpgradeFacet.FacetFunctions({facet: facet, selectors: selectors});
        IDiamondUpgradeTensor(address(diamond)).upgradeDiamond(addFns, new DiamondUpgradeFacet.FacetFunctions[](0), new bytes4[](0), address(0), "", 0, "");
    }

    function _addFacetWithRebuild(address facet, bytes4[] memory selectors) internal {
        DiamondUpgradeFacet.FacetFunctions[] memory addFns = new DiamondUpgradeFacet.FacetFunctions[](1);
        addFns[0] = DiamondUpgradeFacet.FacetFunctions({facet: facet, selectors: selectors});
        IDiamondUpgradeTensor(address(diamond)).upgradeDiamond(addFns, new DiamondUpgradeFacet.FacetFunctions[](0), new bytes4[](0), address(rebuildInit), abi.encodeWithSelector(RebuildInitTensor.init.selector), 0, "");
    }

    function _enableShardedLoupe() internal {
        IDiamondUpgradeTensor(address(diamond)).upgradeDiamond(new DiamondUpgradeFacet.FacetFunctions[](0), new DiamondUpgradeFacet.FacetFunctions[](0), new bytes4[](0), address(initFacet), abi.encodeWithSelector(InitShardedLoupe.init.selector), 0, "");
    }

    function _selectorsManager() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](2);
        sels[0] = TensorManagerFacet.createTensor.selector;
        sels[1] = TensorManagerFacet.destroyTensor.selector;
    }

    function _selectorsRead() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](3);
        sels[0] = TensorReadFacet.meta.selector;
        sels[1] = TensorReadFacet.get.selector;
        sels[2] = TensorReadFacet.getAt.selector;
    }

    function _selectorsWrite() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](2);
        sels[0] = TensorWriteFacet.set.selector;
        sels[1] = TensorWriteFacet.setAt.selector;
    }

    function _selectorsSSTORE2() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](6);
        sels[0] = TensorSSTORE2Facet.writeTensor.selector;
        sels[1] = TensorSSTORE2Facet.readTensor.selector;
        sels[2] = TensorSSTORE2Facet.readAt.selector;
        sels[3] = TensorSSTORE2Facet.payloadChunkCount.selector;
        sels[4] = TensorSSTORE2Facet.payloadChunkAt.selector;
        sels[5] = TensorSSTORE2Facet.payloadChunkBytes.selector;
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
