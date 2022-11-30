// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract MockProductsModule {
  function isProductOwner(
    uint256,
    uint256,
    address
  ) external pure returns (bool isAllowed) {
    isAllowed = true;
  }

  function availableUnits(
    uint256,
    uint256
  ) external pure returns (uint256 units, bool isInfinite) {
    units = 6392;
    isInfinite = false;
  }
}
