// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @param nftAddress           Address of the NFTs that give discount
/// @param discount             Discount - can be fixed or percentage
/// @param minQuantity          Minimum quantity of the NFT to get the discount
struct NFTDiscountParams {
    address nftAddress;
    uint256 discount;
    uint256 minQuantity;
}
