// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DiscountParams} from "./DiscountParams.sol";

enum DiscountType {
    Absolute,
    Relative
}

/// @param basePrice          base price for a currency
/// @param isFree             boolean flag that allows purchase when basePrice == 0`
/// @param discountType       type of discount, can be `Absolute` or `Relative`
/// @param nftDiscounts       array of structs {asset address, absolute/relative discount, min quantity}
struct ProductDiscounts {
    uint240 basePrice;
    bool isFree;
    DiscountType discountType;
    DiscountParams[] discountsArray;
}
