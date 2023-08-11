// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {DSTestPlus} from "lib/solmate/src/test/utils/DSTestPlus.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";
import {ERC721GatedDiscount} from "src/ERC721GatedDiscount/ERC721GatedDiscount.sol";
import {DiscountParams, Strategy} from "src/ERC721GatedDiscount/structs/DiscountParams.sol";
import {NFTDiscountParams} from "src/ERC721GatedDiscount/structs/NFTDiscountParams.sol";
import {CurrenciesParams} from "src/ERC721GatedDiscount/structs/CurrenciesParams.sol";
import {ERC721PresetMinterPauserAutoId} from "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

address constant ETH = address(0);
address constant USDC = address(1);
uint256 constant slicerId = 0;
uint256 constant productId = 1;
address constant owner = address(0);
address constant buyer = address(10);

contract LinearVRGDATest is DSTestPlus {
    ERC721GatedDiscount erc721GatedDiscount;
    MockProductsModule productsModule;
    ERC721PresetMinterPauserAutoId nftOne;

    uint256 basePrice = 1000;

    function setUp() public {
        productsModule = new MockProductsModule();
        erc721GatedDiscount = new ERC721GatedDiscount(address(productsModule));

        nftOne = new ERC721PresetMinterPauserAutoId(
            "NFTOne",
            "NFT1",
            "https://nft.one/"
        );
        nftOne.mint(buyer);
    }

    function testDeploy() public {
        assertTrue(address(erc721GatedDiscount) != address(0));
    }

    function testSetProductPrice__ETH() public {
        NFTDiscountParams[] memory discounts = new NFTDiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] = NFTDiscountParams({
            nftAddress: address(nftOne),
            discount: 100
        });

        CurrenciesParams[] memory currenciesParams = new CurrenciesParams[](1);
        currenciesParams[0] = CurrenciesParams(
            ETH,
            basePrice,
            Strategy.Fixed,
            false,
            discounts
        );

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(
            slicerId,
            productId,
            currenciesParams
        );

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) = erc721GatedDiscount
            .productPrice(slicerId, productId, ETH, 1, buyer, "");

        assertTrue(ethPrice == basePrice - 100);
        assertTrue(currencyPrice == 0);
    }
}
