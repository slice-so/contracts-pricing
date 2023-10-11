// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    uint256 public constant tokenId = 1;

    constructor() ERC1155("Test ERC1155") {}

    function mint(address to) external {
        _mint(to, tokenId, 100, "");
    }
}
