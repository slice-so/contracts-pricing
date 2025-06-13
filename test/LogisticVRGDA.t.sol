// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {unsafeDiv, wadLn, toWadUnsafe, toDaysWadUnsafe, fromDaysWadUnsafe} from "../utils/SignedWadMath.sol";

import "./mocks/MockLogisticVRGDAPrices.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";
import "forge-std/console2.sol";

uint256 constant ONE_THOUSAND_YEARS = 356 days * 1000;

uint256 constant MAX_SELLABLE = 6392;

uint256 constant slicerId = 0;
uint256 constant productId = 1;
int128 constant targetPriceConstant = 69.42e18;
uint128 constant min = 1e18;
int256 constant priceDecayPercent = 0.31e18;
int256 constant timeScale = 0.0023e18;
int256 constant logisticLimitAdjusted = int256((MAX_SELLABLE + 1) * 2e18);
int256 constant logisticLimitDoubled = int256((MAX_SELLABLE + 1e18) * 2e18);

contract LogisticVRGDATest is Test {
    MockLogisticVRGDAPrices vrgda;
    MockProductsModule productsModule;

    function setUp() public {
        productsModule = new MockProductsModule();
        vrgda = new MockLogisticVRGDAPrices(address(productsModule));

        LogisticVRGDAParams[] memory logisticParams = new LogisticVRGDAParams[](1);
        logisticParams[0] = LogisticVRGDAParams(targetPriceConstant, min, timeScale);
        address[] memory ethCurrency = new address[](1);
        ethCurrency[0] = address(0);
        address[] memory erc20Currency = new address[](1);
        erc20Currency[0] = address(20);

        vm.startPrank(address(0));
        vrgda.setProductPrice(slicerId, productId, ethCurrency, logisticParams, priceDecayPercent);
        vrgda.setProductPrice(slicerId, productId, erc20Currency, logisticParams, priceDecayPercent);
        vm.stopPrank();
    }

    function testTargetPrice() public {
        uint256 sold = 0;
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 logisticFactor = unsafeDiv(logisticLimit * 2e18, toWadUnsafe(sold + 1) + logisticLimit);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        // Warp to the target sale time so that the VRGDA price equals the target price.
        vm.warp(block.timestamp + fromDaysWadUnsafe(vrgda.getTargetSaleTime(logisticFactor, timeScale)));

        uint256 cost = vrgda.getVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            logisticLimit,
            logisticLimit * 2e18,
            sold,
            timeScale,
            min
        );
        assertApproxEqAbs(cost, uint256(uint128(targetPriceConstant)), 1e13);
    }

    function testPricingBasic() public {
        // Our VRGDA targets this number of mints at given time.
        uint256 timeDelta = 120 days;
        uint256 numMint = 876;
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.warp(block.timestamp + timeDelta);

        uint256 cost = vrgda.getVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            logisticLimit,
            logisticLimit * 2e18,
            numMint,
            timeScale,
            min
        );

        // Equal within 2 percent since num mint is rounded from true decimal amount.
        assertApproxEqRel(cost, uint256(uint128(targetPriceConstant)), 0.02e18);
    }

    function testPricingMin() public {
        // Our VRGDA targets this number of mints at given time.
        uint256 timeDelta = 120 days;
        uint256 numMint = 793;
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.warp(block.timestamp + timeDelta);

        uint256 cost = vrgda.getVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            logisticLimit,
            logisticLimit * 2e18,
            numMint,
            timeScale,
            min
        );
        assertEq(cost, min);
    }

    function testPricingAdjustedByQuantity() public {
        // Our VRGDA targets this number of mints at given time.
        uint256 timeDelta = 120 days;
        uint256 numMint = 876;
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.warp(block.timestamp + timeDelta);

        uint256 costProduct1 = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            numMint,
            timeScale,
            min,
            1
        );
        uint256 costProduct2 = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            numMint + 1,
            timeScale,
            min,
            1
        );
        uint256 costProduct3 = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            numMint + 2,
            timeScale,
            min,
            1
        );
        uint256 costMultiple = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            numMint,
            timeScale,
            min,
            3
        );

        assertApproxEqAbs(costMultiple, uint256(costProduct1 + costProduct2 + costProduct3), 0.00001e18);
    }

    function testSetMultiplePrices() public {
        // uint256 targetPriceTest = 7.3013e18;
        uint256 productIdTest = 2;
        LogisticVRGDAParams[] memory logisticParams = new LogisticVRGDAParams[](2);
        logisticParams[0] = LogisticVRGDAParams(targetPriceConstant, min, timeScale);
        logisticParams[1] = LogisticVRGDAParams(targetPriceConstant, min, timeScale);
        address[] memory currencies = new address[](2);
        currencies[0] = address(0);
        currencies[1] = address(20);

        vm.startPrank(address(0));
        vrgda.setProductPrice(slicerId, productIdTest, currencies, logisticParams, priceDecayPercent);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        (uint256 ethPrice, uint256 currencyPrice) =
            vrgda.productPrice(slicerId, productIdTest, address(0), 1, address(0), "");

        // assertApproxEqAbs(uint256(targetPriceTest), ethPrice, 1e18);
        assertNotEq(ethPrice, 0);
        assertEq(currencyPrice, 0);

        (uint256 ethPrice2, uint256 currencyPrice2) =
            vrgda.productPrice(slicerId, productId, address(20), 1, address(0), "");

        assertEq(ethPrice2, 0);
        assertNotEq(currencyPrice2, 0);
    }

    function testProductPriceEth() public {
        address ethCurrency = address(0);

        // Our VRGDA targets this number of mints at given time.
        uint256 timeDelta = 10 days;
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.warp(block.timestamp + timeDelta);

        uint256 cost = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            0,
            timeScale,
            min,
            1
        );

        (uint256 ethPrice, uint256 currencyPrice) =
            vrgda.productPrice(slicerId, productId, ethCurrency, 1, address(0), "");

        assertApproxEqAbs(cost, ethPrice, 0.00001e18);
        assertEq(currencyPrice, 0);
    }

    function testProductPriceErc20() public {
        address erc20Currency = address(20);

        // Our VRGDA targets this number of mints at given time.
        uint256 timeDelta = 10 days;
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.warp(block.timestamp + timeDelta);

        uint256 cost = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            0,
            timeScale,
            min,
            1
        );

        (uint256 ethPrice, uint256 currencyPrice) =
            vrgda.productPrice(slicerId, productId, erc20Currency, 1, address(0), "");

        assertApproxEqAbs(cost, currencyPrice, 0.00001e18);
        assertEq(ethPrice, 0);
    }

    function testProductPriceMultiple() public {
        address ethCurrency = address(0);

        // Our VRGDA targets this number of mints at given time.
        uint256 timeDelta = 10 days;
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.warp(block.timestamp + timeDelta);

        uint256 costMultiple = vrgda.getAdjustedVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            toDaysWadUnsafe(block.timestamp),
            toWadUnsafe(MAX_SELLABLE + 1),
            0,
            timeScale,
            min,
            3
        );
        (uint256 ethPrice,) = vrgda.productPrice(slicerId, productId, ethCurrency, 3, address(0), "");

        assertApproxEqAbs(costMultiple, ethPrice, 5e14);
    }

    function testGetTargetSaleTimeDoesNotRevertEarly() public view {
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 logisticFactor = unsafeDiv(logisticLimit * 2e18, toWadUnsafe(MAX_SELLABLE) + logisticLimit);

        vrgda.getTargetSaleTime(logisticFactor, timeScale);
    }

    function testGetTargetSaleTimeRevertsWhenExpected() public {
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 logisticFactor = unsafeDiv(logisticLimit * 2e18, toWadUnsafe(MAX_SELLABLE + 1) + logisticLimit);

        vm.expectRevert("UNDEFINED");
        vrgda.getTargetSaleTime(logisticFactor, timeScale);
    }

    function testNoOverflowForMostTokens(uint256 timeSinceStart, uint256 sold) public view {
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vrgda.getVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            int256(bound(timeSinceStart, 0 days, ONE_THOUSAND_YEARS * 1e18)),
            logisticLimit,
            logisticLimit * 2e18,
            bound(sold, 0, 1730),
            timeScale,
            min
        );
    }

    function testNoOverflowForAllTokens(uint256 timeSinceStart, uint256 sold) public view {
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vrgda.getVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            int256(bound(timeSinceStart, 3870 days * 1e18, ONE_THOUSAND_YEARS * 1e18)),
            logisticLimit,
            logisticLimit * 2e18,
            bound(sold, 0, 6391),
            timeScale,
            min
        );
    }

    function test_RevertOverflow_BeyondLimitTokens(uint256 timeSinceStart, uint256 sold) public {
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        vm.expectRevert();
        vrgda.getVRGDALogisticPrice(
            targetPriceConstant,
            decayConstant,
            int256(bound(timeSinceStart, 0, ONE_THOUSAND_YEARS * 1e18)),
            logisticLimit,
            logisticLimit * 2e18,
            bound(sold, 6392, type(uint128).max),
            timeScale,
            min
        );
    }

    function testAlwaysTargetPriceInRightConditions(uint256 sold) public view {
        sold = bound(sold, 0, MAX_SELLABLE - 1);
        int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);
        int256 logisticFactor = unsafeDiv(logisticLimit * 2e18, toWadUnsafe(sold + 1) + logisticLimit);

        assertApproxEqAbs(
            vrgda.getVRGDALogisticPrice(
                targetPriceConstant,
                decayConstant,
                vrgda.getTargetSaleTime(logisticFactor, timeScale),
                logisticLimit,
                logisticLimit * 2e18,
                sold,
                timeScale,
                min
            ),
            uint256(uint128(targetPriceConstant)),
            0.00001e18
        );
    }
}
