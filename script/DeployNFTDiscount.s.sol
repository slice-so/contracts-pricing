// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import "forge-std/Script.sol";
import {NFTDiscount} from "../src/TieredDiscount/NFTDiscount/NFTDiscount.sol";

contract DeployScript is Script {
    function run() external {

        // address productsModule = 0x689Bba0e25c259b205ECe8e6152Ee1eAcF307f5F; // mainnet
        // address productsModule = 0xcA6b9D59849EC880e82210e9cb8237E1d0cAA69e; // goerli testnet
        // address productsModule = 0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d; // goerli staging
        // address productsModule = 0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d; // base goerli
        address productsModule = 0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84; // base
        // address productsModule = 0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf; // optimism

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        new NFTDiscount(productsModule);

        vm.stopBroadcast();
    }
}
