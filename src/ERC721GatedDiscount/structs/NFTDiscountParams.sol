// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @param nftAddress         Address of the NFT
/// @param discount           Discount can be fixed or percentage

struct NFTDiscountParams {
  address nftAddress;
  uint256 discount;
}
