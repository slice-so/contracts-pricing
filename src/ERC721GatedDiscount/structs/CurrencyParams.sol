// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NFTDiscountParams} from "./NFTDiscountParams.sol";
import {DiscountType} from "./DiscountParams.sol";

/// @param currency             currency address
/// @param basePrice            base price for a currency
/// @param discountType         type of discount, can be `Absolute` or `Relative`
/// @param discounts            array of NFTDiscountParams
struct CurrencyParams {
    address currency;
    uint248 basePrice;
    DiscountType discountType;
    NFTDiscountParams[] discounts;
}
