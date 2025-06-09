// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

/**
 * Helper contract to enforce correct chain selection in scripts
 */
abstract contract WithChainIdValidation is Script {

    address public constant CREATE3_FACTORY = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

    address public immutable PRODUCTS_MODULE;

    constructor(uint256 chainId, address productsModule) {
        require(block.chainid == chainId, 'CHAIN_ID_MISMATCH');
        PRODUCTS_MODULE = productsModule;
    }

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}

abstract contract EthereumScript is WithChainIdValidation {
    constructor() WithChainIdValidation(1, 0x689Bba0e25c259b205ECe8e6152Ee1eAcF307f5F) {}
}

abstract contract GoerliScript is WithChainIdValidation {
    constructor() WithChainIdValidation(5, 0xcA6b9D59849EC880e82210e9cb8237E1d0cAA69e) {}
}

abstract contract OptimismScript is WithChainIdValidation {
    constructor() WithChainIdValidation(10, 0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf) {}
}

abstract contract BaseScript is WithChainIdValidation {
    constructor() WithChainIdValidation(8453, 0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84) {}
}

abstract contract BaseGoerliScript is WithChainIdValidation {
    constructor() WithChainIdValidation(84531, 0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d) {}
}