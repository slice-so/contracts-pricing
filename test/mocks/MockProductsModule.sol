// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockProductsModule {
  function isProductOwner(
    uint256,
    uint256,
    address account
  ) external pure returns (bool isAllowed) {
    isAllowed = account == address(0);
  }

  function availableUnits(uint256, uint256)
    external
    pure
    returns (uint256 units, bool isInfinite)
  {
    units = 6392;
    isInfinite = false;
  }
}
