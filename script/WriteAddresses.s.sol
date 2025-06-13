// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {SetUpContractsList} from "../utils/ScriptUtils.sol";

contract WriteAddressesScript is SetUpContractsList {
    constructor() SetUpContractsList("src") {}

    function run(string memory contractName) external {
        writeAddressesJson(contractName);
    }
}
