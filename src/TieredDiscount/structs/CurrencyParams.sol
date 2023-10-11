// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DiscountParams} from "./DiscountParams.sol";
import {DiscountType} from "./ProductDiscounts.sol";

/// @param currency             currency address
/// @param basePrice            base price for a currency
/// @param isFree               boolean flag that allows purchase when basePrice == 0`
/// @param discountType         type of discount, can be `Absolute` or `Relative`
/// @param discounts            array of DiscountParams
struct CurrencyParams {
    address currency;
    uint240 basePrice;
    bool isFree;
    DiscountType discountType;
    DiscountParams[] discounts;
}
