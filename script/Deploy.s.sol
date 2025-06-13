// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseScript, SetUpContractsList} from "../utils/ScriptUtils.sol";
import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract DeployScript is BaseScript, SetUpContractsList {
    constructor() SetUpContractsList("src") {}

    function run(string memory contractName) public broadcast returns (address contractAddress) {
        contractAddress = deployCode(contractName, abi.encode(PRODUCTS_MODULE));
    }

    function run() external returns (address contractAddress, string memory contractName) {
        contractName = _promptContractName();
        contractAddress = run(contractName);
    }

    function _promptContractName() internal returns (string memory contractName) {
        string memory prompt = "\nPricing strategies available to deploy:\n";
        string memory lastFolder = "";
        for (uint256 i = 0; i < contractNames.length; i++) {
            string memory folder = _getFolderName(contractNames[i].path);
            if (i == 0 || keccak256(bytes(folder)) != keccak256(bytes(lastFolder))) {
                prompt = string.concat(prompt, "\n");
                prompt = string.concat(prompt, folder, "\n");
                lastFolder = folder;
            }
            prompt = string.concat(prompt, "    ", vm.toString(contractNames[i].id), ") ", contractNames[i].name, "\n");
        }
        prompt = string.concat(prompt, "\nEnter the number of the contract to deploy");

        uint256 contractId = vm.promptUint(prompt);
        contractName = contractNames[contractId - 1].name;
        require(bytes(contractName).length > 0, "Invalid ID");
    }
}
