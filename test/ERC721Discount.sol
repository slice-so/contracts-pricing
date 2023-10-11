// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DSTestPlus} from "lib/solmate/src/test/utils/DSTestPlus.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";
import {
    NFTDiscount,
    ProductDiscounts,
    DiscountType,
    DiscountParams,
    CurrencyParams,
    NFTType
} from "src/TieredDiscount/NFTDiscount/NFTDiscount.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";

address constant ETH = address(0);
address constant USDC = address(1);
uint256 constant slicerId = 0;
uint256 constant productId = 1;
address constant owner = address(0);
address constant buyer = address(10);
uint80 constant fixedDiscountOne = 100;
uint80 constant fixedDiscountTwo = 200;
uint80 constant percentDiscount = 1000; // 10%

contract NFTDiscountTest is DSTestPlus {
    NFTDiscount erc721GatedDiscount;
    MockProductsModule productsModule;
    MockERC721 nftOne = new MockERC721();
    MockERC721 nftTwo = new MockERC721();
    MockERC721 nftThree = new MockERC721();
    MockERC1155 nft1155 = new MockERC1155();

    uint240 basePrice = 1000;
    uint256 quantity = 1;
    uint8 minNftQuantity = 1;

    function setUp() public {
        productsModule = new MockProductsModule();
        erc721GatedDiscount = new NFTDiscount(address(productsModule));

        nftOne.mint(buyer);
    }

    function createDiscount(DiscountParams[] memory discountParams) internal {
        DiscountParams[] memory discounts = new DiscountParams[](discountParams.length);

        for (uint256 i = 0; i < discountParams.length; i++) {
            discounts[i] = discountParams[i];
        }

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);
    }

    function testDeploy() public {
        assertTrue(address(erc721GatedDiscount) != address(0));
    }

    function testSetProductPrice__ETH() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);
    }

    function testSetProductPrice__ERC20() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(currencyPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(ethPrice == 0);
    }

    function testSetProductPrice__ERC1155() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] = DiscountParams({
            nft: address(nft1155),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC1155,
            tokenId: 1
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(currencyPrice == quantity * basePrice);
        assertTrue(ethPrice == 0);

        nft1155.mint(buyer);

        (ethPrice, currencyPrice) = erc721GatedDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(currencyPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(ethPrice == 0);
    }

    function testSetProductPrice__MultipleCurrencies() public {
        DiscountParams[] memory discountsOne = new DiscountParams[](1);
        DiscountParams[] memory discountsTwo = new DiscountParams[](1);
        CurrencyParams[] memory currenciesParams = new CurrencyParams[](2);

        /// set product price with additional custom inputs
        discountsOne[0] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discountsOne);

        /// set product price with different discount for different currency
        discountsTwo[0] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountTwo,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        currenciesParams[1] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discountsTwo);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price for ETH
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);

        /// check product price for USDC
        (uint256 ethPrice2, uint256 usdcPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(ethPrice2 == 0);
        assertTrue(usdcPrice == (quantity * basePrice) - fixedDiscountTwo);
    }

    function testProductPrice__NotNFTOwner() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price for NFT that is not owned by buyer
        discounts[0] = DiscountParams({
            nft: address(nftTwo),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * basePrice);
        assertTrue(currencyPrice == 0);
    }

    function testProductPrice__MinQuantity() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// Buyer owns 1 NFT, but minQuantity is 2
        discounts[0] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity + 1,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * basePrice);
        assertTrue(currencyPrice == 0);

        /// Buyer owns 2 NFTs, minQuantity is 2
        nftOne.mint(buyer);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testProductPrice__HigherDiscount() public {
        DiscountParams[] memory discounts = new DiscountParams[](2);

        /// NFT 2 has higher discount, but buyer owns only NFT 1
        discounts[0] = DiscountParams({
            nft: address(nftTwo),
            discount: fixedDiscountTwo,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });
        discounts[1] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);

        /// Buyer mints NFT 2
        nftTwo.mint(buyer);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testProductPrice__Relative() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: address(nftOne),
            discount: percentDiscount,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        /// set product price with percentage discount
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Relative, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - (basePrice * percentDiscount) / 1e4));
        assertTrue(currencyPrice == 0);
    }

    function testProductPrice__MultipleBoughtQuantity() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: address(nftOne),
            discount: percentDiscount,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        /// set product price with percentage discount
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Relative, discounts);

        hevm.prank(owner);
        erc721GatedDiscount.setProductPrice(slicerId, productId, currenciesParams);

        // buy multiple products
        quantity = 6;

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - (basePrice * percentDiscount) / 1e4));
        assertTrue(currencyPrice == 0);
    }

    function testSetProductPrice__Edit_Add() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: address(nftTwo),
            discount: fixedDiscountTwo,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        // mint NFT 2
        nftTwo.mint(buyer);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(currencyPrice == 0);

        discounts = new DiscountParams[](2);

        /// edit product price, with more NFTs and first NFT has higher discount but buyer owns only the second
        discounts[0] = DiscountParams({
            nft: address(nftThree),
            discount: fixedDiscountOne + 10,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        discounts[1] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testSetProductPrice__Edit_Remove() public {
        DiscountParams[] memory discounts = new DiscountParams[](2);

        // mint NFT 2
        nftTwo.mint(buyer);

        /// edit product price, with more NFTs and first NFT has higher discount but buyer owns only the second
        discounts[0] = DiscountParams({
            nft: address(nftThree),
            discount: fixedDiscountOne + 10,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        discounts[1] = DiscountParams({
            nft: address(nftOne),
            discount: fixedDiscountOne,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);

        discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: address(nftTwo),
            discount: fixedDiscountTwo,
            minQuantity: minNftQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            erc721GatedDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(currencyPrice == 0);
    }
}
