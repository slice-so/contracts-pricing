// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Function.sol";
import "./SubSlicerProduct.sol";
import "./ProductPrice.sol";
import "./Purchases.sol";

/**
 * @notice Struct related to product info.
 *
 * @param purchases Mapping of quantity bought by addresses
 * @param prices Mapping with prices set for the product for each allowed currency
 * @param subSlicerProducts Mapping with Array of subProducts
 * @param externalCall `Function` struct containing the params to execute an external call during purchase
 * @param data Metadata containing the public information about the product
 * @param purchaseData Metadata containing the purchase information/procedure for the buyers
 * @param creator Address of the account who created the product
 * @param priceEditTimestamp Timestamp of last time the product price was edited
 * @param availableUnits Number of available units on sale
 * @param maxUnitsPerBuyer Maximum amount of units allowed to purchase for a buyer
 * @param packedBooleans boolean flags ordered from the right: [IsFree, IsInfinite]
 */
struct Product {
    mapping(address => Purchases) purchases;
    mapping(address => ProductPrice) prices;
    SubSlicerProduct[] subSlicerProducts;
    Function externalCall;
    bytes data;
    bytes purchaseData;
    address creator;
    uint40 priceEditTimestamp;
    uint32 availableUnits;
    uint8 maxUnitsPerBuyer;
    uint8 packedBooleans;
    // uint32 categoryIndex;
}
