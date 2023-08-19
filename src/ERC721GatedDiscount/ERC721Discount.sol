// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import {IProductsModule} from "../Slice/interfaces/IProductsModule.sol";
import {ProductDiscounts, DiscountType} from "./structs/ProductDiscounts.sol";
import {CurrencyParams} from "./structs/CurrencyParams.sol";
import {NFTDiscountParams} from "./structs/NFTDiscountParams.sol";

/**
 *   @title    ERC721Discount - Slice pricing strategy
 *   @author   Dom-Mac <@zerohex_eth>
 *   @author   jacopo <@jj_ranalli>
 *   @notice   Product prices with discounts based on NFT ownership
 */

contract ERC721Discount is ISliceProductPrice {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotProductOwner();
    error InvalidDiscountType();

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable productsModuleAddress;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 slicerId => mapping(uint256 productId => mapping(address currency => ProductDiscounts))) public
        productDiscounts;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _productsModuleAddress) {
        productsModuleAddress = _productsModuleAddress;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if msg.sender is owner of a product. Used to manage access to `setProductPrice`.
     */
    modifier onlyProductOwner(uint256 slicerId, uint256 productId) {
        if (!IProductsModule(productsModuleAddress).isProductOwner(slicerId, productId, msg.sender)) {
            revert NotProductOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set NFTs and related discount for product.
     * @dev Inside `currencyParams` array, the discounts must be sorted in descending order
     *
     * @param slicerId ID of the slicer to set the price params for.
     * @param productId ID of the product to set the price params for.
     * @param currencyParams Array of `CurrencyParams` structs,
     *                         remeber to pass discounts sorted from highest to lowest
     */
    function setProductPrice(uint256 slicerId, uint256 productId, CurrencyParams[] memory currencyParams)
        external
        onlyProductOwner(slicerId, productId)
    {
        /// For each strategy, grouped by currency
        for (uint256 i; i < currencyParams.length;) {
            /// Ref of `CurrencyParams` struct
            CurrencyParams memory params = currencyParams[i];

            DiscountParams storage discountParamsRef = productParams[slicerId][productId][params.currency];

            // Set the values for the storage reference
            discountParamsRef.basePrice = params.basePrice;
            discountParamsRef.discountType = params.discountType;

            /// Access to array of NFTDiscountParams for a specific slicer, product and currency
            NFTDiscountParams[] memory newDiscounts = params.discounts;

            uint256 oldLength = discountParamsRef.discountsArray.length;
            uint256 newLength = newDiscounts.length;
            uint256 maxLength = newLength > oldLength ? newLength : oldLength;

            for (uint256 j; j < maxLength;) {
                /// Manually copy each element from memory to storage on DiscountParams
                /// Handle the case where the new array is shorter than the old one or vice versa
                if (j < oldLength && j < newLength) {
                    // Update in place
                    discountParamsRef.discountsArray[j] = newDiscounts[j];
                } else if (j >= oldLength) {
                    // Append new discounts
                    discountParamsRef.discountsArray.push(newDiscounts[j]);
                } else if (j >= newLength) {
                    // Remove old discounts
                    discountParamsRef.discountsArray.pop();
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
     * @param slicerId ID of the slicer being queried
     * @param productId ID of the product being queried
     * @param currency Currency chosen for the purchase
     * @param quantity Number of units purchased
     * @param buyer Address of the buyer
     *
     * @return ethPrice and currencyPrice of product.
     */
    function productPrice(
        uint256 slicerId,
        uint256 productId,
        address currency,
        uint256 quantity,
        address buyer,
        bytes memory
    ) public view override returns (uint256 ethPrice, uint256 currencyPrice) {
        /// Access to DiscountParams for a specific slicer, product and currency
        DiscountParams memory discountParams = productParams[slicerId][productId][currency];

        /// Based on the strategy, discount represents a value or a %.
        /// If user does not have an NFT, discount will be 0.
        uint256 discount = _getDiscount(discountParams, buyer);

        uint256 price = discount != 0
            ? _getPriceBasedOnDiscountType(discountParams.basePrice, discountParams.discountType, discount, quantity)
            : quantity * discountParams.basePrice;

        // Set ethPrice or currencyPrice based on chosen currency
        // TODO: Make sure a price is always returned, otherwise people could purchase for free by pointing to an unset currency
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
     * @param discountParams `DiscountParams` struct
     * @param buyer Address of the buyer
     *
     * @return Discount value
     */
    function _getDiscount(DiscountParams memory discountParams, address buyer) internal view returns (uint256) {
        NFTDiscountParams[] memory discounts = discountParams.discountsArray;
        uint256 length = discounts.length;
        NFTDiscountParams memory el;

        for (uint256 i; i < length;) {
            el = discounts[i];
            // Check if user has at enough NFT to qualify for the discount
            if (el.nft.balanceOf(buyer) >= el.minQuantity) {
                return el.discount;
            }

            unchecked {
                ++i;
            }
        }

        // Otherwise discount will be 0.
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
    ) internal pure returns (uint256 price) {
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
