// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { DSTestPlus } from "lib/solmate/src/test/utils/DSTestPlus.sol";

import { wadLn, toWadUnsafe, toDaysWadUnsafe, fromDaysWadUnsafe } from "src/utils/SignedWadMath.sol";

import { MockLinearVRGDAPrices } from "./mocks/MockLinearVRGDAPrices.sol";
import { MockProductsModule } from "./mocks/MockProductsModule.sol";

uint256 constant ONE_THOUSAND_YEARS = 356 days * 1000;

uint256 constant MAX_SELLABLE = 6392;

uint256 constant slicerId = 0;
uint256 constant productId = 1;
int256 constant targetPriceConstant = 69.42e18;
int256 constant priceDecayPercent = 0.31e18;
int256 constant perTimeUnit = 2e18;

contract LinearVRGDATest is DSTestPlus {
  MockLinearVRGDAPrices vrgda;
  MockProductsModule productsModule;

  function setUp() public {
    productsModule = new MockProductsModule();
    vrgda = new MockLinearVRGDAPrices(address(productsModule));

    int256[] memory targetPrice = new int256[](1);
    targetPrice[0] = targetPriceConstant;
    address[] memory ethCurrency = new address[](1);
    ethCurrency[0] = address(0);
    address[] memory erc20Currency = new address[](1);
    erc20Currency[0] = address(20);

    hevm.startPrank(address(0));
    vrgda.setProductPrice(
      slicerId,
      productId,
      ethCurrency,
      targetPrice,
      priceDecayPercent,
      perTimeUnit
    );
    vrgda.setProductPrice(
      slicerId,
      productId,
      erc20Currency,
      targetPrice,
      priceDecayPercent,
      perTimeUnit
    );
    hevm.stopPrank();
  }

  function testTargetPrice() public {
    // Warp to the target sale time so that the VRGDA price equals the target price.
    hevm.warp(
      block.timestamp +
        fromDaysWadUnsafe(vrgda.getTargetSaleTime(1e18, perTimeUnit))
    );

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);
    uint256 cost = vrgda.getVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      0,
      perTimeUnit
    );
    assertRelApproxEq(cost, uint256(targetPriceConstant), 0.00001e18);
  }

  function testPricingBasic() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 120 days;
    uint256 numMint = 239;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);
    uint256 cost = vrgda.getVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint,
      perTimeUnit
    );
    assertRelApproxEq(cost, uint256(targetPriceConstant), 0.00001e18);
  }

  function testPricingAdjustedByQuantity() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 120 days;
    uint256 numMint = 239;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 costProduct1 = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint,
      perTimeUnit,
      1
    );
    uint256 costProduct2 = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint + 1,
      perTimeUnit,
      1
    );
    uint256 costProduct3 = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint + 2,
      perTimeUnit,
      1
    );
    uint256 costMultiple = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint,
      perTimeUnit,
      3
    );

    assertRelApproxEq(
      costMultiple,
      uint256(costProduct1 + costProduct2 + costProduct3),
      0.00001e18
    );
  }

  function testAlwaystargetPriceInRightConditions(uint256 sold) public {
    sold = bound(sold, 0, type(uint128).max);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);
    assertRelApproxEq(
      vrgda.getVRGDAPrice(
        targetPriceConstant,
        decayConstant,
        vrgda.getTargetSaleTime(toWadUnsafe(sold + 1), perTimeUnit),
        sold,
        perTimeUnit
      ),
      uint256(targetPriceConstant),
      0.00001e18
    );
  }

  function testSetMultiplePrices() public {
    uint256 productId = 2;
    int256[] memory targetPrices = new int256[](2);
    targetPrices[0] = targetPriceConstant;
    targetPrices[1] = targetPriceConstant;
    address[] memory currencies = new address[](2);
    currencies[0] = address(0);
    currencies[1] = address(20);

    hevm.startPrank(address(0));
    vrgda.setProductPrice(
      slicerId,
      productId,
      currencies,
      targetPrices,
      priceDecayPercent,
      perTimeUnit
    );
    hevm.stopPrank();

    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 0.5 days;

    hevm.warp(block.timestamp + timeDelta);

    (uint256 ethPrice, uint256 currencyPrice) = vrgda.productPrice(
      slicerId,
      productId,
      address(0),
      1,
      address(0),
      ""
    );

    assertRelApproxEq(uint256(targetPriceConstant), ethPrice, 0.00001e18);
    assertEq(currencyPrice, 0);

    (uint256 ethPrice2, uint256 currencyPrice2) = vrgda.productPrice(
      slicerId,
      productId,
      address(20),
      1,
      address(0),
      ""
    );

    assertEq(ethPrice2, 0);
    assertRelApproxEq(uint256(targetPriceConstant), currencyPrice2, 0.00001e18);
  }

  function testProductPriceEth() public {
    address ethCurrency = address(0);

    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 cost = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      0,
      perTimeUnit,
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
    address erc20Currency = address(20);

    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 cost = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      0,
      perTimeUnit,
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
    address ethCurrency = address(0);

    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 costMultiple = vrgda.getAdjustedVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      0,
      perTimeUnit,
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
}
