// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title ERC721Mod
 * @notice Minimal ERC-721 facet with mint, burn, transfer, and approvals.
 */
contract ERC721Mod {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    error AlreadyInitialized();
    error TokenDoesNotExist(uint256 _tokenId);
    error TransferCallerNotOwnerNorApproved(address _caller);
    error TransferFromIncorrectOwner(address _from, uint256 _tokenId, address _owner);
    error TransferToZeroAddress();
    error ApproveCallerNotOwnerNorApproved(address _caller);
    error ApprovalToCurrentOwner(address _owner);
    error ApproveQueryForNonexistentToken(uint256 _tokenId);
    error ERC721ReceiverRejectedTokens(address _receiver, uint256 _tokenId);
    error MintToZeroAddress();
    error TokenAlreadyMinted(uint256 _tokenId);
    error BurnCallerNotOwnerNorApproved(address _caller);

    bytes32 internal constant STORAGE_POSITION = keccak256("compose.erc721.mod");
    bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;

    struct ERC721Storage {
        string name;
        string symbol;
        mapping(uint256 tokenId => address owner) owners;
        mapping(address owner => uint256 balance) balances;
        mapping(uint256 tokenId => address approved) tokenApprovals;
        mapping(address owner => mapping(address operator => bool isApproved)) operatorApprovals;
        bool initialized;
    }

    interface IERC721Receiver {
        function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns (bytes4);
    }

    function getStorage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function initERC721(string calldata _name, string calldata _symbol) external {
        ERC721Storage storage s = getStorage();
        if (s.initialized) {
            revert AlreadyInitialized();
        }
        s.name = _name;
        s.symbol = _symbol;
        s.initialized = true;
    }

    function name() external view returns (string memory) {
        return getStorage().name;
    }

    function symbol() external view returns (string memory) {
        return getStorage().symbol;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        if (_owner == address(0)) {
            return 0;
        }
        return getStorage().balances[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = getStorage().owners[_tokenId];
        if (owner == address(0)) {
            revert TokenDoesNotExist(_tokenId);
        }
        return owner;
    }

    function approve(address _approved, uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        address owner = s.owners[_tokenId];
        if (owner == address(0)) {
            revert ApproveQueryForNonexistentToken(_tokenId);
        }
        if (_approved == owner) {
            revert ApprovalToCurrentOwner(owner);
        }
        if (msg.sender != owner && s.operatorApprovals[owner][msg.sender] == false) {
            revert ApproveCallerNotOwnerNorApproved(msg.sender);
        }
        s.tokenApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        if (getStorage().owners[_tokenId] == address(0)) {
            revert ApproveQueryForNonexistentToken(_tokenId);
        }
        return getStorage().tokenApprovals[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        ERC721Storage storage s = getStorage();
        if (msg.sender == _operator) {
            revert ApprovalToCurrentOwner(_operator);
        }
        s.operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return getStorage().operatorApprovals[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        address owner = s.owners[_tokenId];
        if (owner == address(0)) {
            revert TokenDoesNotExist(_tokenId);
        }
        if (owner != _from) {
            revert TransferFromIncorrectOwner(_from, _tokenId, owner);
        }
        if (_isApprovedOrOwner(msg.sender, owner, _tokenId, s) == false) {
            revert TransferCallerNotOwnerNorApproved(msg.sender);
        }
        if (_to == address(0)) {
            revert TransferToZeroAddress();
        }
        _clearApproval(_tokenId, s);
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        bytes memory emptyData = "";
        _safeTransfer(_from, _to, _tokenId, emptyData);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external {
        _safeTransfer(_from, _to, _tokenId, _data);
    }

    function mint(address _to, uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        if (_to == address(0)) {
            revert MintToZeroAddress();
        }
        if (s.owners[_tokenId] != address(0)) {
            revert TokenAlreadyMinted(_tokenId);
        }
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
        emit Transfer(address(0), _to, _tokenId);
    }

    function burn(uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        address owner = s.owners[_tokenId];
        if (owner == address(0)) {
            revert TokenDoesNotExist(_tokenId);
        }
        if (_isApprovedOrOwner(msg.sender, owner, _tokenId, s) == false) {
            revert BurnCallerNotOwnerNorApproved(msg.sender);
        }
        _clearApproval(_tokenId, s);
        s.balances[owner] -= 1;
        delete s.owners[_tokenId];
        emit Transfer(owner, address(0), _tokenId);
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        if (_interfaceId == 0x80ac58cd) {
            return true;
        }
        if (_interfaceId == 0x01ffc9a7) {
            return true;
        }
        if (_interfaceId == 0x5b5e139f) {
            return true;
        }
        return false;
    }

    function _safeTransfer(address _from, address _to, uint256 _tokenId, bytes memory _data) internal {
        transferFrom(_from, _to, _tokenId);
        if (_to.code.length > 0) {
            bytes4 retval = IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            if (retval != ERC721_RECEIVED) {
                revert ERC721ReceiverRejectedTokens(_to, _tokenId);
            }
        }
    }

    function _clearApproval(uint256 _tokenId, ERC721Storage storage s) internal {
        if (s.tokenApprovals[_tokenId] != address(0)) {
            delete s.tokenApprovals[_tokenId];
        }
    }

    function _isApprovedOrOwner(address _spender, address _owner, uint256 _tokenId, ERC721Storage storage s) internal view returns (bool) {
        if (_spender == _owner) {
            return true;
        }
        if (s.tokenApprovals[_tokenId] == _spender) {
            return true;
        }
        if (s.operatorApprovals[_owner][_spender]) {
            return true;
        }
        return false;
    }
}