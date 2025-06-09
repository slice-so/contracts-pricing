// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {BaseScript} from "./utils/ScriptUtils.sol";
// import {CREATE3Factory} from "create3-factory/CREATE3Factory.sol";
import {LinearVRGDAPrices} from "../src/VRGDA/LinearVRGDAPrices.sol";
import {LogisticVRGDAPrices} from "../src/VRGDA/LogisticVRGDAPrices.sol";

contract DeployVRGDAScript is BaseScript {
//     function run() external broadcast {
//         CREATE3Factory create3Factory = CREATE3Factory(CREATE3_FACTORY);
//         bytes32 saltLin = keccak256(bytes(vm.envString("SALT_VRGDA_LINEAR")));
//         bytes32 saltLog = keccak256(bytes(vm.envString("SALT_VRGDA_LOGISTIC")));
//         create3Factory.deploy(
//             saltLin,
//             bytes.concat(
//                 type(LinearVRGDAPrices).creationCode,
//                 abi.encode(PRODUCTS_MODULE)
//             )
//         );
//         create3Factory.deploy(
//         saltLog,
//             bytes.concat(
//                 type(LogisticVRGDAPrices).creationCode,
//                 abi.encode(PRODUCTS_MODULE)
//             )
//         );
//   }
}
