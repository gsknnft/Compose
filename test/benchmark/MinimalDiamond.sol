// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

enum FacetCutAction {
    Add,
    Replace,
    Remove
}

struct FacetAndPosition {
    address facet;
    uint32 position;
}

struct DiamondStorage {
    mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
    bytes4[] selectors;
}

struct FacetCut {
    address facetAddress;
    FacetCutAction action;
    bytes4[] functionSelectors;
}

struct DiamondArgs {
    address init;
    bytes initCalldata;
}

/// @notice Minimal diamond harness for benchmarks (no ownership, no metadata)
contract MinimalDiamond {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function initialize(FacetCut[] memory _diamondCut, DiamondArgs memory _args) external {
        for (uint256 i; i < _diamondCut.length; i++) {
            FacetCut memory cut = _diamondCut[i];
            if (cut.action == FacetCutAction.Add) {
                _addFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Replace) {
                _replaceFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == FacetCutAction.Remove) {
                _removeFunctions(cut.functionSelectors);
            }
        }

        if (_args.init != address(0)) {
            (bool success, bytes memory err) = _args.init.delegatecall(_args.initCalldata);
            if (!success) {
                if (err.length == 0) {
                    revert("Init failed");
                }
                assembly {
                    revert(add(err, 0x20), mload(err))
                }
            }
        }
    }

    fallback() external payable {
        DiamondStorage storage s = getStorage();
        address facet = s.facetAndPosition[msg.sig].facet;
        if (facet == address(0)) {
            revert("Selector not found");
        }

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}

    function _addFunctions(address _facet, bytes4[] memory _functionSelectors) internal {
        if (_facet.code.length == 0) {
            revert("No bytecode");
        }
        if (_functionSelectors.length == 0) {
            revert("No selectors");
        }

        DiamondStorage storage s = getStorage();
        uint32 selectorPosition = uint32(s.selectors.length);
        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            if (s.facetAndPosition[selector].facet != address(0)) {
                revert("Selector exists");
            }
            s.facetAndPosition[selector] = FacetAndPosition({facet: _facet, position: selectorPosition});
            s.selectors.push(selector);
            selectorPosition++;
        }
    }

    function _replaceFunctions(address _facet, bytes4[] memory _functionSelectors) internal {
        if (_facet.code.length == 0) {
            revert("No bytecode");
        }
        if (_functionSelectors.length == 0) {
            revert("No selectors");
        }

        DiamondStorage storage s = getStorage();
        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            FacetAndPosition memory old = s.facetAndPosition[selector];
            if (old.facet == address(0)) {
                revert("Selector missing");
            }
            if (old.facet == _facet) {
                revert("Same facet");
            }
            s.facetAndPosition[selector].facet = _facet;
        }
    }

    function _removeFunctions(bytes4[] memory _functionSelectors) internal {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            FacetAndPosition memory old = s.facetAndPosition[selector];
            if (old.facet == address(0)) {
                revert("Selector missing");
            }

            selectorCount--;
            if (old.position != selectorCount) {
                bytes4 lastSelector = s.selectors[selectorCount];
                s.selectors[old.position] = lastSelector;
                s.facetAndPosition[lastSelector].position = old.position;
            }

            s.selectors.pop();
            delete s.facetAndPosition[selector];
        }
    }
}