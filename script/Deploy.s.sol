// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseScript, SetUpContracts} from "../utils/ScriptUtils.sol";
import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract DeployScript is BaseScript, SetUpContracts {
    constructor() SetUpContracts("src") {}

    function run() external broadcast returns (address contractAddress) {
        string memory contractName = _promptContractName();
        contractAddress = deployCode(contractName, abi.encode(PRODUCTS_MODULE));
    }

    function run(string memory contractName) external broadcast returns (address contractAddress) {
        contractAddress = deployCode(contractName, abi.encode(PRODUCTS_MODULE));
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

    function _getFolderName(string memory path) internal view returns (string memory folderName) {
        bytes memory pathBytes = bytes(path);
        uint256 lastSlash = 0;
        uint256 prevSlash = 0;
        for (uint256 i = 0; i < pathBytes.length; i++) {
            if (pathBytes[i] == "/") {
                prevSlash = lastSlash;
                lastSlash = i;
            }
        }
        // If only one slash, return the first folder after src
        if (lastSlash == 0) return CONTRACT_PATH;
        // Find the folder name (between prevSlash and lastSlash)
        uint256 start = prevSlash == 0 ? 0 : prevSlash + 1;
        uint256 len = lastSlash - start;
        if (len == 0) return CONTRACT_PATH;
        bytes memory folderBytes = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            folderBytes[i] = pathBytes[start + i];
        }
        folderName = string(folderBytes);
    }
}
