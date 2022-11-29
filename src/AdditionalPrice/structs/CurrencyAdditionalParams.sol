// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @param customInputId  Custom input identifier
/// @param additionalPrice Price to add to the base price

struct CurrencyAdditionalParams {
  uint256 customInputId;
  uint256 additionalPrice;
}
