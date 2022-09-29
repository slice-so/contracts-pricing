// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { DSTestPlus } from "lib/solmate/src/test/utils/DSTestPlus.sol";

import { wadLn, toWadUnsafe } from "src/utils/SignedWadMath.sol";

import { MockLinearVRGDAPrices } from "../mocks/MockLinearVRGDAPrices.sol";
import { MockProductsModule } from "../mocks/MockProductsModule.sol";

import { console } from "lib/forge-std/src/console.sol";
import { Vm } from "lib/forge-std/src/Vm.sol";

contract LinearVRGDACorrectnessTest is DSTestPlus {
  Vm public constant vm = Vm(address(hevm));

  // Sample parameters for differential fuzzing campaign.
  uint256 immutable maxTimeframe = 356 days * 10;
  uint256 immutable maxSellable = 10000;

  uint256 constant slicerId = 0;
  uint256 constant productId = 1;
  int256 immutable targetPriceConstant = 69.42e18;
  int256 immutable priceDecayPercent = 0.31e18;
  int256 immutable perTimeUnit = 2e18;

  MockLinearVRGDAPrices vrgda;
  MockProductsModule productsModule;

  function setUp() public {
    productsModule = new MockProductsModule();
    vrgda = new MockLinearVRGDAPrices(address(productsModule));

    int256[] memory targetPrice = new int256[](1);
    targetPrice[0] = targetPriceConstant;
    address[] memory ethCurrency = new address[](1);
    ethCurrency[0] = address(0);

    hevm.prank(address(0));
    vrgda.setProductPrice(
      slicerId,
      productId,
      ethCurrency,
      targetPrice,
      priceDecayPercent,
      perTimeUnit
    );
  }

  function testFFICorrectness() public {
    // 10 days in wads.
    uint256 timeSinceStart = 10e18;

    // Number sold, slightly ahead of schedule.
    uint256 numSold = 25;
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    uint256 actualPrice = vrgda.getVRGDAPrice(
      targetPriceConstant,
      decayConstant,
      int256(timeSinceStart),
      numSold,
      perTimeUnit
    );

    uint256 expectedPrice = calculatePrice(
      targetPriceConstant,
      priceDecayPercent,
      perTimeUnit,
      timeSinceStart,
      numSold
    );

    console.log("actual price", actualPrice);
    console.log("expected price", expectedPrice);

    // Check approximate equality.
    assertRelApproxEq(expectedPrice, actualPrice, 0.00001e18);

    // Sanity check that prices are greater than zero.
    assertGt(actualPrice, 0);
  }

  // fuzz to test correctness against multiple inputs
  function testFFICorrectnessFuzz(uint256 timeSinceStart, uint256 numSold)
    public
  {
    // Bound fuzzer inputs to acceptable ranges.
    numSold = bound(numSold, 0, maxSellable);
    timeSinceStart = bound(timeSinceStart, 0, maxTimeframe);

    // Convert to wad days for convenience.
    timeSinceStart = (timeSinceStart * 1e18) / 1 days;
    int256 decayConstant = wadLn(1e18 - priceDecayPercent);

    // We wrap this call in a try catch because the getVRGDAPrice is expected to
    // revert for degenerate cases. When this happens, we just continue campaign.
    try
      vrgda.getVRGDAPrice(
        targetPriceConstant,
        decayConstant,
        int256(timeSinceStart),
        numSold,
        perTimeUnit
      )
    returns (uint256 actualPrice) {
      uint256 expectedPrice = calculatePrice(
        targetPriceConstant,
        priceDecayPercent,
        perTimeUnit,
        timeSinceStart,
        numSold
      );

      if (expectedPrice < 0.0000001e18) return; // For really small prices, we expect divergence, so we skip.

      assertRelApproxEq(expectedPrice, actualPrice, 0.00001e18);
    } catch {}
  }

  function calculatePrice(
    int256 _targetPrice,
    int256 _priceDecreasePercent,
    int256 _perUnitTime,
    uint256 _timeSinceStart,
    uint256 _numSold
  ) private returns (uint256) {
    string[] memory inputs = new string[](13);
    inputs[0] = "python3";
    inputs[1] = "test/correctness/python/compute_price.py";
    inputs[2] = "linear";
    inputs[3] = "--time_since_start";
    inputs[4] = vm.toString(_timeSinceStart);
    inputs[5] = "--num_sold";
    inputs[6] = vm.toString(_numSold);
    inputs[7] = "--targetPrice";
    inputs[8] = vm.toString(uint256(_targetPrice));
    inputs[9] = "--priceDecayPercent";
    inputs[10] = vm.toString(uint256(_priceDecreasePercent));
    inputs[11] = "--per_time_unit";
    inputs[12] = vm.toString(uint256(_perUnitTime));

    return abi.decode(vm.ffi(inputs), (uint256));
  }
}
