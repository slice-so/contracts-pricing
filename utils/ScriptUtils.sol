// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {ISliceCore} from "./Slice/interfaces/ISliceCore.sol";
import {IProductsModule} from "./Slice/interfaces/IProductsModule.sol";
import {IFundsModule} from "./Slice/interfaces/IFundsModule.sol";
import {VmSafe} from "forge-std/Vm.sol";

/**
 * Helper contract to enforce correct chain selection in scripts
 */
abstract contract WithChainIdValidation is Script {
    ISliceCore public immutable SLICE_CORE;
    IProductsModule public immutable PRODUCTS_MODULE;
    IFundsModule public immutable FUNDS_MODULE;

    constructor(uint256 chainId, address sliceCore, address productsModule, address fundsModule) {
        require(block.chainid == chainId, "CHAIN_ID_MISMATCH");
        SLICE_CORE = ISliceCore(sliceCore);
        PRODUCTS_MODULE = IProductsModule(productsModule);
        FUNDS_MODULE = IFundsModule(fundsModule);
    }

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}

abstract contract EthereumScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            1,
            0x21da1b084175f95285B49b22C018889c45E1820d,
            0x689Bba0e25c259b205ECe8e6152Ee1eAcF307f5F,
            0x6bcA3Dfd6c2b146dcdd460174dE95Fd1e26960BC
        )
    {}
}

abstract contract OptimismScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            10,
            0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84,
            0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf,
            0x115978100953D0Aa6f2f8865d11Dc5888f728370
        )
    {}
}

abstract contract BaseScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            8453,
            0x5Cef0380cE0aD3DAEefef8bDb85dBDeD7965adf9,
            0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84,
            0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf
        )
    {}
}

abstract contract BaseGoerliScript is WithChainIdValidation {
    constructor()
        WithChainIdValidation(
            84531,
            0xAE38a794E839D045460839ABe288a8e5C28B0fc6,
            0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d,
            0x5Cef0380cE0aD3DAEefef8bDb85dBDeD7965adf9
        )
    {}
}

abstract contract SetUpContracts is Script {
    struct ContractMap {
        uint256 id;
        string path;
        string name;
    }

    string public CONTRACT_PATH;

    ContractMap[] public contractNames;
    uint256 startId = 1;

    constructor(string memory path) {
        CONTRACT_PATH = path;
    }

    function setUp() public {
        _recordContractsOnPath(CONTRACT_PATH);
    }

    function _recordContractsOnPath(string memory path) internal {
        VmSafe.DirEntry[] memory files = vm.readDir(path);
        for (uint256 i = 0; i < files.length; i++) {
            VmSafe.DirEntry memory file = files[i];
            if (file.isDir) {
                _recordContractsOnPath(file.path);
            } else if (_endsWith(file.path, ".sol")) {
                string memory content = vm.readFile(file.path);
                if (_containsContractKeyword(content) && !_containsAbstractContractKeyword(content)) {
                    string memory contractName = _extractContractName(content);
                    contractNames.push(
                        ContractMap({id: startId++, path: string(abi.encodePacked(file.path)), name: contractName})
                    );
                }
            }
        }
    }

    function _extractContractName(string memory content) internal pure returns (string memory) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyword = bytes("contract ");
        for (uint256 i = 0; i < contentBytes.length - keyword.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < keyword.length; j++) {
                if (contentBytes[i + j] != keyword[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                // Found "contract ", now extract the name
                uint256 start = i + keyword.length;
                uint256 end = start;
                while (
                    end < contentBytes.length
                        && (
                            (contentBytes[end] >= 0x30 && contentBytes[end] <= 0x39) // 0-9
                                || (contentBytes[end] >= 0x41 && contentBytes[end] <= 0x5A) // A-Z
                                || (contentBytes[end] >= 0x61 && contentBytes[end] <= 0x7A) // a-z
                                || (contentBytes[end] == 0x5F)
                        ) // _
                ) {
                    end++;
                }
                bytes memory nameBytes = new bytes(end - start);
                for (uint256 k = 0; k < end - start; k++) {
                    nameBytes[k] = contentBytes[start + k];
                }
                return string(nameBytes);
            }
        }
        return "";
    }

    function _containsContractKeyword(string memory content) internal pure returns (bool) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyword = bytes("contract ");
        for (uint256 i = 0; i <= contentBytes.length - keyword.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < keyword.length; j++) {
                if (contentBytes[i + j] != keyword[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }
        return false;
    }

    function _containsAbstractContractKeyword(string memory content) internal pure returns (bool) {
        bytes memory contentBytes = bytes(content);
        bytes memory keyword = bytes("abstract contract ");
        for (uint256 i = 0; i <= contentBytes.length - keyword.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < keyword.length; j++) {
                if (contentBytes[i + j] != keyword[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }
        return false;
    }

    // Helper to check if a string ends with a suffix
    function _endsWith(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);
        if (suffixBytes.length > strBytes.length) return false;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (strBytes[strBytes.length - suffixBytes.length + i] != suffixBytes[i]) {
                return false;
            }
        }
        return true;
    }
}
