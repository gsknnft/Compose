// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";

import {ComponentsHarness} from "src/diamondTensors/mocks/ComponentsHarness.sol";
import {MaliciousERC721} from "src/diamondTensors/mocks/MaliciousERC721.sol";
import {CapsuleDiamondFacet} from "src/diamondTensors/components/CapsuleDiamondFacet.sol";
import {MaliciousVerifier} from "src/diamondTensors/mocks/MaliciousVerifier.sol";

contract ReentrancyComponentsTest is Test {
    ComponentsHarness internal components;
    MaliciousERC721 internal nft;

    bytes32 internal tensorAId;
    bytes32 internal tensorBId;

    function setUp() public {
        components = new ComponentsHarness();
        nft = new MaliciousERC721();

        uint256[] memory shape = new uint256[](2);
        shape[0] = 2;
        shape[1] = 2;

        tensorAId = components.createTensor(2, shape, _seed("A"), 1);
        tensorBId = components.createTensor(2, shape, _seed("B"), 1);

        nft.mint(address(this), 1);
    }

    function testBindNFTNotReentrantFromOwnerOf() public {
        bytes memory reenterData = abi.encodeWithSelector(
            components.bindNFT.selector,
            address(nft),
            uint256(1),
            tensorBId,
            false
        );

        nft.setReenter(address(components), reenterData, true);

        components.bindNFT(address(nft), 1, tensorAId, false);

        assertEq(components.tensorOf(address(nft), 1), tensorAId);
    }

    function _seed(string memory label) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(label, address(this)));
    }
}

contract ReentrancyCapsuleFacetTest is Test {
    CapsuleDiamondFacet internal capsule;
    MaliciousVerifier internal verifier;

    function setUp() public {
        verifier = new MaliciousVerifier();
        capsule = new CapsuleDiamondFacet(address(verifier));
    }

    function testSubmitCapsuleNotReentrantViaVerifier() public {
        CapsuleDiamondFacet.Capsule memory cap = CapsuleDiamondFacet.Capsule({
            root: keccak256("root-reenter"),
            stateHash: keccak256("state-reenter"),
            sender: address(this),
            nonce: 1,
            srcChainId: 1,
            srcSlot: 1
        });

        bytes memory reenterData = abi.encodeWithSelector(
            capsule.submitCapsule.selector,
            cap,
            bytes("\x12\x34")
        );

        verifier.setReenter(address(capsule), reenterData, true);

        assertTrue(capsule.submitCapsule(cap, bytes("\x12\x34")));

        vm.expectRevert(bytes("replay"));
        capsule.submitCapsule(cap, bytes("\x12\x34"));
    }
}
