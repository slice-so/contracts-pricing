// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import "forge-std/Script.sol";

import { LinearVRGDAPrices } from "../src/VRGDA/LinearVRGDAPrices.sol";
import { LogisticVRGDAPrices } from "../src/VRGDA/LogisticVRGDAPrices.sol";

// import { CREATE3Factory } from "create3-factory/CREATE3Factory.sol";

contract DeployScript is Script {
  function run()
    public
    returns (LinearVRGDAPrices linear, LogisticVRGDAPrices logistic)
  {
    // CREATE3Factory create3Factory = CREATE3Factory(
    //   0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf
    // );

    address productsModule = 0x689Bba0e25c259b205ECe8e6152Ee1eAcF307f5F; // mainnet
    // address productsModule = 0xcA6b9D59849EC880e82210e9cb8237E1d0cAA69e; // goerli testnet
    // address productsModule = 0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d; // goerli staging
    // address productsModule = 0x0FD0d9aa44a05Ee158DDf6F01d7dcF503388781d; // base goerli
    // address productsModule = 0xb9d5B99d5D0fA04dD7eb2b0CD7753317C2ea1a84; // base
    // address productsModule = 0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf; // optimism

    // bytes32 saltLin = keccak256(bytes(vm.envString("SALT_LIN")));
    // bytes32 saltLog = keccak256(bytes(vm.envString("SALT_LOG")));
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);

    // linear = LinearVRGDAPrices(
    //   create3Factory.deploy(
    //     saltLin,
    //     bytes.concat(
    //       type(LinearVRGDAPrices).creationCode,
    //       abi.encode(productsModule)
    //     )
    //   )
    // );

    // logistic = LogisticVRGDAPrices(
    //   create3Factory.deploy(
    //     saltLog,
    //     bytes.concat(
    //       type(LogisticVRGDAPrices).creationCode,
    //       abi.encode(productsModule)
    //     )
    //   )
    // );

    linear = new LinearVRGDAPrices(productsModule);
    logistic = new LogisticVRGDAPrices(productsModule);

    vm.stopBroadcast();
  }
}
