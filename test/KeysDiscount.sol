// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DSTestPlus} from "lib/solmate/src/test/utils/DSTestPlus.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";
import {
    KeysDiscount,
    ProductDiscounts,
    DiscountType,
    DiscountParams,
    CurrencyParams,
    IFriendTechShares,
    NFTType
} from "src/TieredDiscount/KeysDiscount/KeysDiscount.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

address constant ETH = address(0);
address constant USDC = address(1);
uint256 constant slicerId = 0;
uint256 constant productId = 1;
address constant owner = address(0);
address constant buyer = address(10);
uint80 constant fixedDiscountOne = 100;
uint80 constant fixedDiscountTwo = 200;
uint80 constant percentDiscount = 1000; // 10%

contract KeysDiscountTest is DSTestPlus, Script {
    KeysDiscount keysDiscount;
    MockProductsModule productsModule;
    IFriendTechShares public constant friendTechShares = IFriendTechShares(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);

    address sharesSubject = 0x95fd28bF8a877604636572Eb8fc58F80ee4F2798;
    address sharesSubjectAlt = address(123);
    address sharesSubjectAlt2 = address(234);

    uint240 basePrice = 1000;
    uint256 quantity = 1;
    uint8 minQuantity = 1;

    function setUp() public {
        string memory rpcUrl = vm.envString("RPC_URL_BASE");
        vm.createSelectFork(rpcUrl, 3557211);

        vm.deal(buyer, 10 ether);

        vm.prank(buyer);
        friendTechShares.buyShares{value: 1 ether}(sharesSubject, 1);

        vm.prank(sharesSubjectAlt);
        friendTechShares.buyShares(sharesSubjectAlt, 1);
        vm.prank(sharesSubjectAlt2);
        friendTechShares.buyShares(sharesSubjectAlt2, 1);

        productsModule = new MockProductsModule();
        keysDiscount = new KeysDiscount(address(productsModule));
    }

    function createDiscount(DiscountParams[] memory discountParams) internal {
        DiscountParams[] memory discounts = new DiscountParams[](discountParams.length);

        for (uint256 i = 0; i < discountParams.length; i++) {
            discounts[i] = discountParams[i];
        }

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        keysDiscount.setProductPrice(slicerId, productId, currenciesParams);
    }

    function testDeploy() public {
        assertTrue(address(keysDiscount) != address(0));
    }

    function testSetProductPrice__ETH() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        keysDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);
    }

    function testSetProductPrice__ERC20() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price with additional custom inputs
        discounts[0] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        currenciesParams[0] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discounts);

        hevm.prank(owner);
        keysDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(currencyPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(ethPrice == 0);
    }

    function testSetProductPrice__MultipleCurrencies() public {
        DiscountParams[] memory discountsOne = new DiscountParams[](1);
        DiscountParams[] memory discountsTwo = new DiscountParams[](1);
        CurrencyParams[] memory currenciesParams = new CurrencyParams[](2);

        /// set product price with additional custom inputs
        discountsOne[0] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Absolute, discountsOne);

        /// set product price with different discount for different currency
        discountsTwo[0] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountTwo,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        currenciesParams[1] = CurrencyParams(USDC, basePrice, false, DiscountType.Absolute, discountsTwo);

        hevm.prank(owner);
        keysDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price for ETH
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);

        /// check product price for USDC
        (uint256 ethPrice2, uint256 usdcPrice) =
            keysDiscount.productPrice(slicerId, productId, USDC, quantity, buyer, "");

        assertTrue(ethPrice2 == 0);
        assertTrue(usdcPrice == (quantity * basePrice) - fixedDiscountTwo);
    }

    function testProductPrice__NotOwner() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// set product price for key that is not owned by buyer
        discounts[0] = DiscountParams({
            nft: address(1),
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * basePrice);
        assertTrue(currencyPrice == 0);
    }

    function testProductPrice__MinQuantity() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        /// Buyer owns 1 key, but minQuantity is 2
        discounts[0] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity + 1,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * basePrice);
        assertTrue(currencyPrice == 0);

        /// Buyer now owns 2 keys, minQuantity is 2
        vm.prank(buyer);
        friendTechShares.buyShares{value: 1 ether}(sharesSubject, 1);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testProductPrice__HigherDiscount() public {
        DiscountParams[] memory discounts = new DiscountParams[](2);

        /// key 2 has higher discount, but buyer owns only key 1
        discounts[0] = DiscountParams({
            nft: sharesSubjectAlt,
            discount: fixedDiscountTwo,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });
        discounts[1] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(currencyPrice == 0);

        /// Buyer mints 1 key of sharesSubjectAlt
        vm.prank(buyer);
        friendTechShares.buyShares{value: 1 ether}(sharesSubjectAlt, 1);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testProductPrice__Relative() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: sharesSubject,
            discount: percentDiscount,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        /// set product price with percentage discount
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Relative, discounts);

        hevm.prank(owner);
        keysDiscount.setProductPrice(slicerId, productId, currenciesParams);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - (basePrice * percentDiscount) / 1e4));
        assertTrue(currencyPrice == 0);
    }

    function testProductPrice__MultipleBoughtQuantity() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: sharesSubject,
            discount: percentDiscount,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        CurrencyParams[] memory currenciesParams = new CurrencyParams[](1);
        /// set product price with percentage discount
        currenciesParams[0] = CurrencyParams(ETH, basePrice, false, DiscountType.Relative, discounts);

        hevm.prank(owner);
        keysDiscount.setProductPrice(slicerId, productId, currenciesParams);

        // buy multiple products
        quantity = 6;

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - (basePrice * percentDiscount) / 1e4));
        assertTrue(currencyPrice == 0);
    }

    function testSetProductPrice__Edit_Add() public {
        DiscountParams[] memory discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: sharesSubjectAlt,
            discount: fixedDiscountTwo,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// Buyer mints 1 key of sharesSubjectAlt
        vm.prank(buyer);
        friendTechShares.buyShares{value: 1 ether}(sharesSubjectAlt, 1);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(currencyPrice == 0);

        discounts = new DiscountParams[](2);

        /// edit product price, with more keys and first key has higher discount but buyer owns only the second
        discounts[0] = DiscountParams({
            nft: sharesSubjectAlt2,
            discount: fixedDiscountOne + 10,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        discounts[1] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);
    }

    function testSetProductPrice__Edit_Remove() public {
        DiscountParams[] memory discounts = new DiscountParams[](2);

        /// Buyer mints 1 key of sharesSubjectAlt
        vm.prank(buyer);
        friendTechShares.buyShares{value: 1 ether}(sharesSubjectAlt, 1);

        /// edit product price, with more keys and first key has higher discount but buyer owns only the second
        discounts[0] = DiscountParams({
            nft: sharesSubjectAlt2,
            discount: fixedDiscountOne + 10,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        discounts[1] = DiscountParams({
            nft: sharesSubject,
            discount: fixedDiscountOne,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 secondEthPrice, uint256 secondCurrencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(secondEthPrice == quantity * (basePrice - fixedDiscountOne));
        assertTrue(secondCurrencyPrice == 0);

        discounts = new DiscountParams[](1);

        discounts[0] = DiscountParams({
            nft: sharesSubjectAlt,
            discount: fixedDiscountTwo,
            minQuantity: minQuantity,
            nftType: NFTType.ERC721,
            tokenId: 0
        });

        createDiscount(discounts);

        /// check product price
        (uint256 ethPrice, uint256 currencyPrice) =
            keysDiscount.productPrice(slicerId, productId, ETH, quantity, buyer, "");

        assertTrue(ethPrice == quantity * (basePrice - fixedDiscountTwo));
        assertTrue(currencyPrice == 0);
    }
}
