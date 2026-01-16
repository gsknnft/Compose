// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice ERC-721 mock that attempts reentrancy during ownerOf.
contract MaliciousERC721 {
    mapping(uint256 => address) private _owners;

    address public reenterTarget;
    bytes public reenterData;
    bool public reenterEnabled;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function mint(address to, uint256 tokenId) external {
        require(to != address(0), "zero address");
        require(_owners[tokenId] == address(0), "already minted");
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function setReenter(
        address target,
        bytes calldata data,
        bool enabled
    ) external {
        reenterTarget = target;
        reenterData = data;
        reenterEnabled = enabled;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        if (reenterEnabled && reenterTarget != address(0)) {
            (bool ok, ) = reenterTarget.staticcall(reenterData);
            require(!ok, "reentrancy succeeded");
        }

        address owner = _owners[tokenId];
        require(owner != address(0), "nonexistent token");
        return owner;
    }
}
