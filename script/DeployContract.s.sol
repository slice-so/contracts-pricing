// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseScript} from "./utils/ScriptUtils.sol";
import {console} from "lib/forge-std/src/console.sol";

contract DeployScript is BaseScript {
    function run(string memory contractName) broadcast
        external 
    {
        console.log("contractName", contractName);
    }
}
