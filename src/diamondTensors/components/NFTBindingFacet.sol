// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "../../interfaces/ERC721/IERC721.sol";
import "../TensorStorage.sol";

/// @title NFTBindingFacet
/// @notice Binds ERC-721 tokens to tensor-based memory.
/// @dev NFTs act as identity pointers; tensors store evolving state.
contract NFTBindingFacet {
    event NFTBound(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 indexed tensorId,
        bool immutableBinding
    );

    event NFTRebound(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 oldTensor,
        bytes32 newTensor
    );

    event NFTUnbound(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 indexed tensorId
    );

    // ---------------------------------------------------------------------
    // Binding
    // ---------------------------------------------------------------------

    /// @notice Bind an NFT to a tensor.
    /// @param nft ERC-721 contract address
    /// @param tokenId Token ID
    /// @param tensorId Tensor memory to bind
    /// @param immutableBinding If true, binding cannot be changed
    function bindNFT(
        address nft,
        uint256 tokenId,
        bytes32 tensorId,
        bool immutableBinding
    ) external {
        _requireNFTOwner(nft, tokenId);

        TensorStorage.Layout storage l = TensorStorage.layout();
        require(l.exists[tensorId], "tensor missing");

        TensorStorage.NFTBinding storage b = l.bindings[nft][tokenId];
        require(b.boundAt == 0, "already bound");

        b.nft = nft;
        b.tokenId = tokenId;
        b.tensorId = tensorId;
        b.immutableBinding = immutableBinding;
        b.boundAt = uint64(block.timestamp);

        emit NFTBound(nft, tokenId, tensorId, immutableBinding);
    }

    /// ---------------------------------------------------------------------
    // Rebinding (if mutable)
    // ---------------------------------------------------------------------

    /// @notice Rebind NFT to a new tensor (only if mutable).
    function rebindNFT(
        address nft,
        uint256 tokenId,
        bytes32 newTensorId
    ) external {
        _requireNFTOwner(nft, tokenId);

        TensorStorage.Layout storage l = TensorStorage.layout();
        TensorStorage.NFTBinding storage b = l.bindings[nft][tokenId];
        require(b.boundAt != 0, "not bound");
        require(!b.immutableBinding, "binding immutable");

        require(l.exists[newTensorId], "tensor missing");

        bytes32 old = b.tensorId;
        b.tensorId = newTensorId;

        emit NFTRebound(nft, tokenId, old, newTensorId);
    }

    function unbindNFT(address nft, uint256 tokenId) external {
        _requireNFTOwner(nft, tokenId);

        TensorStorage.Layout storage l = TensorStorage.layout();
        TensorStorage.NFTBinding storage b = l.bindings[nft][tokenId];
        require(b.boundAt != 0, "not bound");
        require(!b.immutableBinding, "binding immutable");

        bytes32 oldTensorId = b.tensorId;
        delete l.bindings[nft][tokenId];

        emit NFTUnbound(nft, tokenId, oldTensorId);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getBinding(address nft, uint256 tokenId)
        external
        view
        returns (TensorStorage.NFTBinding memory)
    {
        return TensorStorage.layout().bindings[nft][tokenId];
    }

    function tensorOf(address nft, uint256 tokenId)
        external
        view
        returns (bytes32)
    {
        return TensorStorage.layout().bindings[nft][tokenId].tensorId;
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    function _requireNFTOwner(address nft, uint256 tokenId) internal view {
        require(
            IERC721(nft).ownerOf(tokenId) == msg.sender,
            "not NFT owner"
        );
    }
}
