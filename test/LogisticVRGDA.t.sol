// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { DSTestPlus } from "lib/solmate/src/test/utils/DSTestPlus.sol";

import { unsafeDiv, wadLn, toWadUnsafe, toDaysWadUnsafe, fromDaysWadUnsafe } from "src/utils/SignedWadMath.sol";

import { MockLogisticVRGDAPrices } from "./mocks/MockLogisticVRGDAPrices.sol";
import { MockProductsModule } from "./mocks/MockProductsModule.sol";
import "forge-std/console2.sol";

uint256 constant ONE_THOUSAND_YEARS = 356 days * 1000;

uint256 constant MAX_SELLABLE = 6392;

uint256 constant slicerId = 0;
uint256 constant productId = 1;
address constant ethCurrency = address(0);
address constant erc20Currency = address(20);
int256 constant targetPrice = 69.42e18;
int256 constant priceDecayPercent = 0.31e18;
int256 constant timeScale = 0.0023e18;
int256 constant logisticLimitAdjusted = int256((MAX_SELLABLE + 1) * 2e18);
int256 constant logisticLimitDoubled = int256((MAX_SELLABLE + 1e18) * 2e18);

contract LogisticVRGDATest is DSTestPlus {
  MockLogisticVRGDAPrices vrgda;
  MockProductsModule productsModule;

  function setUp() public {
    productsModule = new MockProductsModule();
    vrgda = new MockLogisticVRGDAPrices(address(productsModule));

    hevm.startPrank(address(0));
    vrgda.setProductPrice(
      slicerId,
      productId,
      ethCurrency,
      targetPrice,
      priceDecayPercent,
      timeScale
    );
    vrgda.setProductPrice(
      slicerId,
      productId,
      erc20Currency,
      targetPrice,
      priceDecayPercent,
      timeScale
    );
    hevm.stopPrank();
  }

  function testTargetPrice() public {
    uint256 sold = 0;
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 logisticFactor = unsafeDiv(
      logisticLimit * 2e18,
      toWadUnsafe(sold + 1) + logisticLimit
    );
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    // Warp to the target sale time so that the VRGDA price equals the target price.
    hevm.warp(
      block.timestamp +
        fromDaysWadUnsafe(vrgda.getTargetSaleTime(logisticFactor, timeScale))
    );

    uint256 cost = vrgda.getVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      logisticLimit,
      logisticLimit * 2e18,
      sold,
      timeScale
    );
    assertRelApproxEq(cost, uint256(targetPrice), 0.0000001e18);
  }

  function testPricingBasic() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 120 days;
    uint256 numMint = 876;
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    hevm.warp(block.timestamp + timeDelta);

    uint256 cost = vrgda.getVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      logisticLimit,
      logisticLimit * 2e18,
      numMint,
      timeScale
    );

    // Equal within 2 percent since num mint is rounded from true decimal amount.
    assertRelApproxEq(cost, uint256(targetPrice), 0.02e18);
  }

  function testPricingAdjustedByQuantity() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 120 days;
    uint256 numMint = 876;
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    hevm.warp(block.timestamp + timeDelta);

    uint256 costProduct1 = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      numMint,
      timeScale,
      1
    );
    uint256 costProduct2 = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      numMint + 1,
      timeScale,
      1
    );
    uint256 costProduct3 = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      numMint + 2,
      timeScale,
      1
    );
    uint256 costMultiple = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      numMint,
      timeScale,
      3
    );

    assertRelApproxEq(
      costMultiple,
      uint256(costProduct1 + costProduct2 + costProduct3),
      0.00001e18
    );
  }

  function testProductPriceEth() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    hevm.warp(block.timestamp + timeDelta);

    uint256 cost = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      0,
      timeScale,
      1
    );

    (uint256 ethPrice, uint256 currencyPrice) = vrgda.productPrice(
      slicerId,
      productId,
      ethCurrency,
      1,
      address(0),
      ""
    );

    assertRelApproxEq(cost, ethPrice, 0.00001e18);
    assertEq(currencyPrice, 0);
  }

  function testProductPriceErc20() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    hevm.warp(block.timestamp + timeDelta);

    uint256 cost = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      0,
      timeScale,
      1
    );

    (uint256 ethPrice, uint256 currencyPrice) = vrgda.productPrice(
      slicerId,
      productId,
      erc20Currency,
      1,
      address(0),
      ""
    );

    assertRelApproxEq(cost, currencyPrice, 0.00001e18);
    assertEq(ethPrice, 0);
  }

  function testProductPriceMultiple() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    hevm.warp(block.timestamp + timeDelta);

    uint256 costMultiple = vrgda.getAdjustedVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      toWadUnsafe(MAX_SELLABLE + 1),
      0,
      timeScale,
      3
    );
    (uint256 ethPrice, ) = vrgda.productPrice(
      slicerId,
      productId,
      ethCurrency,
      3,
      address(0),
      ""
    );

    assertRelApproxEq(costMultiple, ethPrice, 0.00001e18);
  }

  function testGetTargetSaleTimeDoesNotRevertEarly() public view {
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 logisticFactor = unsafeDiv(
      logisticLimit * 2e18,
      toWadUnsafe(MAX_SELLABLE) + logisticLimit
    );

    vrgda.getTargetSaleTime(logisticFactor, timeScale);
  }

  function testGetTargetSaleTimeRevertsWhenExpected() public {
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 logisticFactor = unsafeDiv(
      logisticLimit * 2e18,
      toWadUnsafe(MAX_SELLABLE + 1) + logisticLimit
    );

    hevm.expectRevert("UNDEFINED");
    vrgda.getTargetSaleTime(logisticFactor, timeScale);
  }

  function testNoOverflowForMostTokens(uint256 timeSinceStart, uint256 sold)
    public
  {
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    vrgda.getVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      int256(bound(timeSinceStart, 0 days, ONE_THOUSAND_YEARS * 1e18)),
      logisticLimit,
      logisticLimit * 2e18,
      bound(sold, 0, 1730),
      timeScale
    );
  }

  function testNoOverflowForAllTokens(uint256 timeSinceStart, uint256 sold)
    public
  {
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    vrgda.getVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      int256(
        bound(timeSinceStart, 3870 days * 1e18, ONE_THOUSAND_YEARS * 1e18)
      ),
      logisticLimit,
      logisticLimit * 2e18,
      bound(sold, 0, 6391),
      timeScale
    );
  }

  function testFailOverflowForBeyondLimitTokens(
    uint256 timeSinceStart,
    uint256 sold
  ) public {
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    vrgda.getVRGDALogisticPrice(
      targetPrice,
      decayConstant,
      int256(bound(timeSinceStart, 0 days, ONE_THOUSAND_YEARS * 1e18)),
      logisticLimit,
      logisticLimit * 2e18,
      bound(sold, 6392, type(uint128).max),
      timeScale
    );
  }

  function testAlwaysTargetPriceInRightConditions(uint256 sold) public {
    sold = bound(sold, 0, MAX_SELLABLE - 1);
    int256 logisticLimit = toWadUnsafe(MAX_SELLABLE + 1);
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);
    int256 logisticFactor = unsafeDiv(
      logisticLimit * 2e18,
      toWadUnsafe(sold + 1) + logisticLimit
    );

    assertRelApproxEq(
      vrgda.getVRGDALogisticPrice(
        targetPrice,
        decayConstant,
        vrgda.getTargetSaleTime(logisticFactor, timeScale),
        logisticLimit,
        logisticLimit * 2e18,
        sold,
        timeScale
      ),
      uint256(targetPrice),
      0.00001e18
    );
  }
}
