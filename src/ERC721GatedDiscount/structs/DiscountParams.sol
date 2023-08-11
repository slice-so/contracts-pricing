// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NFTDiscountParams} from './NFTDiscountParams.sol';

enum Strategy {
  Fixed,
  Percentage
}

/// @param basePrice          base price for a currency
/// @param strategy           0: Fixed discount (ex. 1000 wei)
///                           1: Percentage discount (ex. 10%)
/// @param dependsOnQuantity  if true, the discount depends on the quantity of products
/// @param nftDiscountsArray  array of structs {NFT address, fixed/percentage discount}
/// @param nftDiscounts       mapping of NFT address to fixed/percentage discount

struct DiscountParams {
  uint256 basePrice;
  Strategy strategy;
  bool dependsOnQuantity;
  NFTDiscountParams[] nftDiscountsArray;
  mapping(address => uint256) nftDiscounts;
}
