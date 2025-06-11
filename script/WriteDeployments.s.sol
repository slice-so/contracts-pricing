// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {SetUpContracts} from "../utils/ScriptUtils.sol";
import {console} from "forge-std/console.sol";
import {NFTDiscount} from "../src/TieredDiscount/NFTDiscount/NFTDiscount.sol";

contract WriteDeploymentsScript is SetUpContracts {
    constructor() SetUpContracts("src") {}

    function run() external {
        string memory json = "final";

        for (uint256 i = 0; i < contractNames.length; i++) {
            string memory objJson = vm.toString(i);
            string memory contractName = contractNames[i].name;
            console.log("Contract name:", contractName);
            address[] memory deployments = vm.getDeployments(contractName, 8453);

            if (deployments.length == 0) {
                continue;
            }

            string memory contractObj = "{}";
            contractObj = vm.serializeAddress(contractObj, "addresses", deployments);
            objJson = vm.serializeString(objJson, contractName, contractObj);
            json = vm.serializeString(json, contractName, objJson);
        }

        vm.writeJson(json, "./deployments/addresses-base.json");
    }
}
