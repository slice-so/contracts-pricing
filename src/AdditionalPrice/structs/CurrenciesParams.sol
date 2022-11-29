// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurrencyAdditionalParams} from './CurrencyAdditionalParams.sol';
import {Strategy} from './AdditionalPriceParams.sol';

/// @param currency currency address for a product
/// @param basePrice base price for a currency
/// @param strategy 0: Custom additional price
///                 1: Percentage
/// @param dependsOnQuantity additional price depends on quantity or not
/// @param additionalPrices array of CurrencyAdditionalParams

struct CurrenciesParams {
  address currency;
  uint256 basePrice;
  Strategy strategy;
  bool dependsOnQuantity;
  CurrencyAdditionalParams[] additionalPrices;
}
