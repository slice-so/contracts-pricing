// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import {IProductsModule} from "../Slice/interfaces/IProductsModule.sol";
import {ProductDiscounts, DiscountType} from "./structs/ProductDiscounts.sol";
import {CurrencyParams} from "./structs/CurrencyParams.sol";
import {NFTDiscountParams} from "./structs/NFTDiscountParams.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 *   @title    ERC721Discount - Slice pricing strategy with discounts based on NFT ownership
 *   @author   Dom-Mac <@zerohex_eth>
 *   @author   jacopo <@jj_ranalli>
 */

contract ERC721Discount is ISliceProductPrice {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotProductOwner();
    error WrongCurrency();
    error InvalidRelativeDiscount();
    error DiscountsNotDescending(address nft);

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
     * @notice Set base price and NFT discounts for a product.
     * @dev Discounts must be sorted in descending order
     *
     * @param slicerId ID of the slicer to set the price params for.
     * @param productId ID of the product to set the price params for.
     * @param currencyParams Array of `CurrencyParams` structs
     */
    function setProductPrice(uint256 slicerId, uint256 productId, CurrencyParams[] memory currencyParams)
        external
        onlyProductOwner(slicerId, productId)
    {
        CurrencyParams memory params;
        NFTDiscountParams[] memory newDiscounts;
        uint256 prevDiscountValue;
        uint256 prevDiscountsLength;
        uint256 currDiscountsLength;
        uint256 maxLength;
        uint256 minLength;
        for (uint256 i; i < currencyParams.length;) {
            params = currencyParams[i];

            ProductDiscounts storage productDiscount = productDiscounts[slicerId][productId][params.currency];

            // Set `productDiscount` values
            productDiscount.basePrice = params.basePrice;
            productDiscount.isFree = params.isFree;
            productDiscount.discountType = params.discountType;

            newDiscounts = params.discounts;
            prevDiscountsLength = productDiscount.discountsArray.length;
            currDiscountsLength = newDiscounts.length;
            maxLength = currDiscountsLength > prevDiscountsLength ? currDiscountsLength : prevDiscountsLength;
            minLength = maxLength == prevDiscountsLength ? currDiscountsLength : prevDiscountsLength;

            for (uint256 j; j < maxLength;) {
                // Check relative discount doesn't exceed max value of 1e4
                if (params.discountType == DiscountType.Relative) {
                    if (newDiscounts[j].discount > 1e4) revert InvalidRelativeDiscount();
                }

                // Check discounts are sorted in descending order
                if (j > 0) {
                    if (newDiscounts[j].discount > prevDiscountValue) {
                        revert DiscountsNotDescending(newDiscounts[j].nft);
                    }
                }

                prevDiscountValue = newDiscounts[j].discount;

                if (j < minLength) {
                    // Update in place
                    productDiscount.discountsArray[j] = newDiscounts[j];
                } else if (j >= prevDiscountsLength) {
                    // Append new discounts
                    productDiscount.discountsArray.push(newDiscounts[j]);
                } else if (j >= currDiscountsLength) {
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
        ProductDiscounts memory discountParams = productDiscounts[slicerId][productId][currency];

        if (discountParams.basePrice == 0) {
            if (!discountParams.isFree) revert WrongCurrency();
        } else {
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
        returns (uint256)
    {
        NFTDiscountParams[] memory discounts = discountParams.discountsArray;
        uint256 length = discounts.length;
        NFTDiscountParams memory el;

        for (uint256 i; i < length;) {
            el = discounts[i];
            // Check if user has at enough NFT to qualify for the discount
            if (IERC721(el.nft).balanceOf(buyer) >= el.minQuantity) {
                return el.discount;
            }

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
