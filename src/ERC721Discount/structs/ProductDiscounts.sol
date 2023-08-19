// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NFTDiscountParams} from "./NFTDiscountParams.sol";

enum DiscountType {
    Absolute,
    Relative
}

/// @param basePrice          base price for a currency
/// @param isFree             boolean flag that allows purchase when basePrice == 0`
/// @param discountType       type of discount, can be `Absolute` or `Relative`
/// @param nftDiscounts       array of structs {NFT address, absolute/relative discount}
struct ProductDiscounts {
    uint240 basePrice;
    bool isFree;
    DiscountType discountType;
    NFTDiscountParams[] discountsArray;
}
