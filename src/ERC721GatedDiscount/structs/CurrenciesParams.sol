// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NFTDiscountParams} from './NFTDiscountParams.sol';
import {Strategy} from './DiscountParams.sol';

/// @param currency             currency address
/// @param basePrice            base price for a currency
/// @param strategy             0: Fixed discount (ex. 1000 wei)
///                             1: Percentage discount (ex. 10%)
/// @param dependsOnQuantity    discount price depends on quantity or not
/// @param discounts            array of NFTDiscountParams

struct CurrenciesParams {
  address currency;
  uint256 basePrice;
  Strategy strategy;
  bool dependsOnQuantity;
  NFTDiscountParams[] discounts;
}
