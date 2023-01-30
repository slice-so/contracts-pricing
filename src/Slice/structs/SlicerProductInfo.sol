// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../structs/Product.sol";

import "../interfaces/ISlicer.sol";

import "@openzeppelin-upgradeable/utils/CountersUpgradeable.sol";

struct SlicerProductInfo {
  CountersUpgradeable.Counter productCounter;
  mapping(uint256 => Product) products;
  uint256 ethBalance;
  address slicerAddress;
}
