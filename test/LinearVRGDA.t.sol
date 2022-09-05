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
address constant ethCurrency = address(0);
address constant erc20Currency = address(20);
int256 constant targetPrice = 69.42e18;
int256 constant priceDecayPercent = 0.31e18;
int256 constant perTimeUnit = 2e18;

contract LinearVRGDATest is DSTestPlus {
  MockLinearVRGDAPrices vrgda;
  MockProductsModule productsModule;

  function setUp() public {
    productsModule = new MockProductsModule();
    vrgda = new MockLinearVRGDAPrices(address(productsModule));

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
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      0,
      perTimeUnit
    );
    assertRelApproxEq(cost, uint256(targetPrice), 0.00001e18);
  }

  function testPricingBasic() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 120 days;
    uint256 numMint = 239;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);
    uint256 cost = vrgda.getVRGDAPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint,
      perTimeUnit
    );
    assertRelApproxEq(cost, uint256(targetPrice), 0.00001e18);
  }

  function testPricingAdjustedByQuantity() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 120 days;
    uint256 numMint = 239;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 costProduct1 = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint,
      perTimeUnit,
      1
    );
    uint256 costProduct2 = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint + 1,
      perTimeUnit,
      1
    );
    uint256 costProduct3 = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
      decayConstant,
      toDaysWadUnsafe(block.timestamp),
      numMint + 2,
      perTimeUnit,
      1
    );
    uint256 costMultiple = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
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

  function testAlwaysTargetPriceInRightConditions(uint256 sold) public {
    sold = bound(sold, 0, type(uint128).max);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);
    assertRelApproxEq(
      vrgda.getVRGDAPrice(
        targetPrice,
        decayConstant,
        vrgda.getTargetSaleTime(toWadUnsafe(sold + 1), perTimeUnit),
        sold,
        perTimeUnit
      ),
      uint256(targetPrice),
      0.00001e18
    );
  }

  function testProductPriceEth() public {
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 cost = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
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
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 cost = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
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
    // Our VRGDA targets this number of mints at given time.
    uint256 timeDelta = 10 days;

    hevm.warp(block.timestamp + timeDelta);

    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 costMultiple = vrgda.getAdjustedVRGDAPrice(
      targetPrice,
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
