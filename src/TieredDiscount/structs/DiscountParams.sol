// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @param asset                address to check ownership against
/// @param discount             discount amount, based on `discountType`
///                             if `discountType` is `Relative`, discount is less than 1e4
/// @param minQuantity          minimum quantity of assets owned to get the discount
struct DiscountParams {
    address asset;
    uint88 discount;
    uint8 minQuantity;
}
