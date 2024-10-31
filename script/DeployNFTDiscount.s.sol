// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {EthereumScript, BaseScript} from "./utils/ScriptUtils.sol";
import {NFTDiscount} from "../src/TieredDiscount/NFTDiscount/NFTDiscount.sol";


/// make deploy-ledger contract=script/DeployNFTDiscount.s.sol:DeployEthereum chain=mainnet

contract DeployEthereum is EthereumScript {
    function run() external broadcast {
        new NFTDiscount(PRODUCTS_MODULE);
    }
}

/// make deploy-ledger contract=script/DeployNFTDiscount.s.sol:DeployBase chain=base

contract DeployBase is BaseScript {
    function run() external broadcast {
        new NFTDiscount(PRODUCTS_MODULE);
    }
}
