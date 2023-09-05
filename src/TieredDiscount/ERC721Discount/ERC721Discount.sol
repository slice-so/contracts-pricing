// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {CurrencyParams, DiscountParams, ProductDiscounts, DiscountType, TieredDiscount} from "../TieredDiscount.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title   ERC721Discount - Slice pricing strategy with discounts based on NFT ownership
 * @author  Dom-Mac <@zerohex_eth>
 * @author  jacopo <@jj_ranalli>
 */

contract ERC721Discount is TieredDiscount {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _productsModuleAddress) TieredDiscount(_productsModuleAddress) {}

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set base price and NFT discounts for a product.
     * @dev Discounts must be sorted in descending order
     *
     * @param slicerId ID of the slicer to set the price params for.
     * @param productId ID of the product to set the price params for.
     * @param allCurrencyParams Array of `CurrencyParams` structs
     */
    function _setProductPrice(uint256 slicerId, uint256 productId, CurrencyParams[] memory allCurrencyParams)
        internal
        virtual
        override
    {
        CurrencyParams memory currencyParams;
        DiscountParams[] memory newDiscounts;
        uint256 prevDiscountValue;
        uint256 prevDiscountsLength;
        uint256 currDiscountsLength;
        uint256 maxLength;
        uint256 minLength;
        for (uint256 i; i < allCurrencyParams.length;) {
            currencyParams = allCurrencyParams[i];

            ProductDiscounts storage productDiscount = productDiscounts[slicerId][productId][currencyParams.currency];

            // Set `productDiscount` values
            productDiscount.basePrice = currencyParams.basePrice;
            productDiscount.isFree = currencyParams.isFree;
            productDiscount.discountType = currencyParams.discountType;

            // Set values used in inner loop
            newDiscounts = currencyParams.discounts;
            prevDiscountsLength = productDiscount.discountsArray.length;
            currDiscountsLength = newDiscounts.length;
            maxLength = currDiscountsLength > prevDiscountsLength ? currDiscountsLength : prevDiscountsLength;
            minLength = maxLength == prevDiscountsLength ? currDiscountsLength : prevDiscountsLength;

            for (uint256 j; j < maxLength;) {
                // If `j` is within bounds of `newDiscounts`
                if (currDiscountsLength > j) {
                    // Check relative discount doesn't exceed max value of 1e4
                    if (currencyParams.discountType == DiscountType.Relative) {
                        if (newDiscounts[j].discount > 1e4) revert InvalidRelativeDiscount();
                    }

                    if (newDiscounts[j].minQuantity == 0) revert InvalidMinQuantity();

                    // Check discounts are sorted in descending order
                    if (j > 0) {
                        if (newDiscounts[j].discount > prevDiscountValue) {
                            revert DiscountsNotDescending(newDiscounts[j]);
                        }
                    }

                    prevDiscountValue = newDiscounts[j].discount;

                    if (j < minLength) {
                        // Update in place
                        productDiscount.discountsArray[j] = newDiscounts[j];
                    } else if (j >= prevDiscountsLength) {
                        // Append new discounts
                        productDiscount.discountsArray.push(newDiscounts[j]);
                    }
                } else {
                    // Remove old discounts
                    productDiscount.discountsArray.pop();
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Function called by Slice protocol to calculate current product price.
     *         Base price is returned if user does not have a discount.
     *
     * @param currency Currency chosen for the purchase
     * @param quantity Number of units purchased
     * @param buyer Address of the buyer
     * @param discountParams `ProductDiscounts` struct
     *
     * @return ethPrice and currencyPrice of product.
     */
    function _productPrice(
        uint256,
        uint256,
        address currency,
        uint256 quantity,
        address buyer,
        bytes memory,
        ProductDiscounts memory discountParams
    ) internal view virtual override returns (uint256 ethPrice, uint256 currencyPrice) {
        uint256 discount = _getHighestDiscount(discountParams, buyer);

        uint256 price = discount != 0
            ? _getPriceBasedOnDiscountType(discountParams.basePrice, discountParams.discountType, discount, quantity)
            : quantity * discountParams.basePrice;

        if (currency == address(0)) {
            ethPrice = price;
        } else {
            currencyPrice = price;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the highest discount available for a user, based on owned NFTs.
     *
     * @param discountParams `ProductDiscounts` struct
     * @param buyer Address of the buyer
     *
     * @return Discount value
     */
    function _getHighestDiscount(ProductDiscounts memory discountParams, address buyer)
        internal
        view
        virtual
        returns (uint256)
    {
        DiscountParams[] memory discounts = discountParams.discountsArray;
        uint256 length = discounts.length;
        DiscountParams memory el;

        address prevAsset;
        uint256 nftBalance;
        for (uint256 i; i < length;) {
            el = discounts[i];

            // Skip retrieving balance if asset is the same as previous iteration
            if (prevAsset != el.nft) {
                nftBalance = IERC721(el.nft).balanceOf(buyer);
            }

            // Check if user has at enough NFT to qualify for the discount
            if (nftBalance >= el.minQuantity) {
                return el.discount;
            }

            prevAsset = el.nft;

            unchecked {
                ++i;
            }
        }

        // Otherwise default to no discount.
        return 0;
    }

    /**
     * @notice Calculate price based on `discountType`
     *
     * @param basePrice Base price of the product
     * @param discountType Type of discount, either `Absolute` or `Relative`
     * @param discount Discount value based on `discountType`
     * @param quantity Number of units purchased
     *
     * @return price of product inclusive of discount.
     */
    function _getPriceBasedOnDiscountType(
        uint256 basePrice,
        DiscountType discountType,
        uint256 discount,
        uint256 quantity
    ) internal pure virtual returns (uint256 price) {
        if (discountType == DiscountType.Absolute) {
            price = (basePrice - discount) * quantity;
        } else {
            uint256 k;
            /// @dev discount cannot be higher than 1e4, as it's checked on `setProductPrice`
            unchecked {
                k = 1e4 - discount;
            }

            price = (basePrice * k * quantity) / 1e4;
        }
    }
}
