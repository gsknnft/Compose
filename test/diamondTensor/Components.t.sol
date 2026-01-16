// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";

import {ComponentsHarness} from "src/diamondTensors/mocks/ComponentsHarness.sol";
import {MockERC721} from "src/diamondTensors/mocks/MockERC721.sol";
import {CapsuleDiamondFacet} from "src/diamondTensors/components/CapsuleDiamondFacet.sol";
import {MockProofVerifier} from "src/diamondTensors/mocks/MockProofVerifier.sol";

contract ComponentsFacetTest is Test {
    ComponentsHarness internal components;
    MockERC721 internal nft;

    address internal owner = address(this);
    address internal other = address(0xBEEF);

    bytes32 internal constant SEED_A = bytes32(hex"1111111111111111111111111111111111111111111111111111111111111111");
    bytes32 internal constant SEED_B = bytes32(hex"2222222222222222222222222222222222222222222222222222222222222222");

    bytes32 internal tensorAId;
    bytes32 internal tensorBId;

    function setUp() public {
        components = new ComponentsHarness();
        nft = new MockERC721();

        uint256[] memory shape = new uint256[](2);
        shape[0] = 2;
        shape[1] = 2;

        tensorAId = components.createTensor(2, shape, SEED_A, 1);
        tensorBId = components.createTensor(2, shape, SEED_B, 1);

        nft.mint(owner, 1);
        nft.mint(owner, 2);
        nft.mint(other, 3);
    }

    function testCapsuleRegistryAppendAndLatest() public {
        vm.expectRevert(bytes("no capsules"));
        components.latestCapsule(tensorAId);

        bytes32 root1 = keccak256(abi.encodePacked("capsule-1"));
        bytes32 root2 = keccak256(abi.encodePacked("capsule-2"));

        components.registerCapsule(tensorAId, root1);
        components.registerCapsule(tensorAId, root2);

        assertEq(components.capsuleCount(tensorAId), 2);
        assertEq(components.capsuleAt(tensorAId, 0).capsuleRoot, root1);
        assertEq(components.latestCapsule(tensorAId).capsuleRoot, root2);
    }

    function testCapsuleRegistryEnforcesOwnership() public {
        bytes32 root = keccak256(abi.encodePacked("capsule-owner"));
        vm.prank(other);
        vm.expectRevert(bytes("not owner"));
        components.registerCapsule(tensorAId, root);
    }

    function testNftBindingOwnershipAndImmutability() public {
        // bind NFT 1 to tensor A (mutable)
        components.bindNFT(address(nft), 1, tensorAId, false);
        assertEq(components.tensorOf(address(nft), 1), tensorAId);

        // rebind to tensor B
        components.rebindNFT(address(nft), 1, tensorBId);
        assertEq(components.tensorOf(address(nft), 1), tensorBId);

        // unbind
        components.unbindNFT(address(nft), 1);
        assertEq(components.getBinding(address(nft), 1).tensorId, bytes32(0));

        // bind NFT 2 immutably
        components.bindNFT(address(nft), 2, tensorAId, true);

        vm.expectRevert(bytes("binding immutable"));
        components.rebindNFT(address(nft), 2, tensorBId);

        vm.expectRevert(bytes("binding immutable"));
        components.unbindNFT(address(nft), 2);

        // non-owner cannot bind
        vm.prank(other);
        vm.expectRevert(bytes("not NFT owner"));
        components.bindNFT(address(nft), 1, tensorAId, false);
    }
}

contract CapsuleDiamondFacetTest is Test {
    CapsuleDiamondFacet internal capsule;
    MockProofVerifier internal verifier;

    address internal owner = address(this);
    address internal other = address(0xCAFE);

    function setUp() public {
        verifier = new MockProofVerifier();
        capsule = new CapsuleDiamondFacet(address(verifier));
    }

    function testAcceptsValidCapsulesAndBlocksReplay() public {
        verifier.setResult(true);

        CapsuleDiamondFacet.Capsule memory cap = CapsuleDiamondFacet.Capsule({
            root: keccak256(abi.encodePacked("root-1")),
            stateHash: keccak256(abi.encodePacked("state-1")),
            sender: owner,
            nonce: 1,
            srcChainId: 1,
            srcSlot: 1
        });

        bytes memory proof = hex"1234";

        assertTrue(capsule.submitCapsule(cap, proof));

        vm.expectRevert(bytes("replay"));
        capsule.submitCapsule(cap, proof);
    }

    function testRejectsInvalidProofsAndNonOwnerVerifierUpdates() public {
        verifier.setResult(false);

        CapsuleDiamondFacet.Capsule memory cap = CapsuleDiamondFacet.Capsule({
            root: keccak256(abi.encodePacked("root-2")),
            stateHash: keccak256(abi.encodePacked("state-2")),
            sender: owner,
            nonce: 2,
            srcChainId: 1,
            srcSlot: 2
        });

        bytes memory proof = hex"1234";

        vm.expectRevert(bytes("invalid proof"));
        capsule.submitCapsule(cap, proof);

        vm.prank(other);
        vm.expectRevert(bytes("not owner"));
        capsule.setVerifier(address(verifier));
    }
}
