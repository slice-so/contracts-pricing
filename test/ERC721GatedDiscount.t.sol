// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {DSTestPlus} from "lib/solmate/src/test/utils/DSTestPlus.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";
import {ERC721GatedDiscount} from "src/ERC721GatedDiscount/ERC721GatedDiscount.sol";
import {DiscountParams, Strategy} from "src/ERC721GatedDiscount/structs/DiscountParams.sol";
import {NFTDiscountParams} from "src/ERC721GatedDiscount/structs/NFTDiscountParams.sol";
import {CurrenciesParams} from "src/ERC721GatedDiscount/structs/CurrenciesParams.sol";

address constant ETH = address(0);

contract LinearVRGDATest is DSTestPlus {
    ERC721GatedDiscount erc721GatedDiscount;
    MockProductsModule productsModule;

    uint256 basePrice = 1000;

    function setUp() public {
        productsModule = new MockProductsModule();
        erc721GatedDiscount = new ERC721GatedDiscount(address(productsModule));
    }

    function testDeploy() public {
        assertTrue(address(erc721GatedDiscount) != address(0));
    }
}
