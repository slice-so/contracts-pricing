// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum Strategy {
  Custom,
  Percentage
}

/// @param basePrice base price for a currency
/// @param strategy 0: Custom additional price
///                 1: Percentage
/// @param dependsOnQuantity additional price depends on quantity or not
/// @param additionalPrices mapping from customInputId to additionalPrice/percentage,

struct AdditionalPriceParams {
  uint256 basePrice;
  Strategy strategy;
  bool dependsOnQuantity;
  mapping(uint256 => uint256) additionalPrices;
}
