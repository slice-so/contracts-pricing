// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @param nft                  NFT address
/// @param discount             discount amount, based on `discountType`
///                             if `discountType` is `Relative`, discount is less than 1e4
/// @param minQuantity          minimum quantity of NFTs owned to get the discount
struct NFTDiscountParams {
    address nft;
    uint88 discount;
    uint8 minQuantity;
}
