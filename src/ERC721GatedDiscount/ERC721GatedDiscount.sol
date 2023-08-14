// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {ISliceProductPrice} from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import {IProductsModule} from "../Slice/interfaces/IProductsModule.sol";
import {DiscountParams, Strategy} from "./structs/DiscountParams.sol";
import {CurrenciesParams} from "./structs/CurrenciesParams.sol";
import {NFTDiscountParams} from "./structs/NFTDiscountParams.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
  @title    NFT gated discount - Slice pricing strategy
  @author   Dom-Mac <@zerohex_eth>
  @author   jj-ranalli
  @notice   - Inherits `ISliceProductPrice` interface
            - Get discount price based on NFT ownership
            - Constructor logic sets Slice `productsModuleAddress` in storage
 */

contract ERC721GatedDiscount is ISliceProductPrice {
    //*********************************************************************//
    // ------------------------ immutable storage ------------------------ //
    //*********************************************************************//

    /**
    @notice Address of the Slice `ProductsModule`
  */
    address public immutable productsModuleAddress;

    //*********************************************************************//
    // ------------------------- mutable storage ------------------------- //
    //*********************************************************************//

    /**
    @notice Mapping from `slicerId` to `productId` to `currency` to `DiscountParams`
  */
    mapping(uint256 => mapping(uint256 => mapping(address => DiscountParams)))
        public productParams;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    constructor(address _productsModuleAddress) {
        productsModuleAddress = _productsModuleAddress;
    }

    //*********************************************************************//
    // ----------------------------- modifiers --------------------------- //
    //*********************************************************************//

    /**
    @notice Check if msg.sender is owner of a product. Used to manage access of `setProductPrice`
            in implementations of this contract.
  */
    modifier onlyProductOwner(uint256 slicerId, uint256 productId) {
        require(
            IProductsModule(productsModuleAddress).isProductOwner(
                slicerId,
                productId,
                msg.sender
            ),
            "NOT_PRODUCT_OWNER"
        );
        _;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /**
    @notice Set NFTs and related discount for product.
    
    @param slicerId ID of the slicer to set the price params for.
    @param productId ID of the product to set the price params for.
    @param currenciesParams Array of `CurrenciesParams` structs, 
                            remeber to pass discounts sorted from highest to lowest
  */
    /**
     @dev Inside currendiesParams array, 
          the discounts must be sorted from highest to lowest
  */
    function setProductPrice(
        uint256 slicerId,
        uint256 productId,
        CurrenciesParams[] memory currenciesParams
    ) external onlyProductOwner(slicerId, productId) {
        /// For each strategy, grouped by currency
        for (uint256 i; i < currenciesParams.length; ) {
            /// Ref of `CurrenciesParams` struct
            CurrenciesParams memory params = currenciesParams[i];

            // Initialize the storage reference for the nftDiscountsArray
            DiscountParams storage discountParamsRef = productParams[slicerId][
                productId
            ][params.currency];

            // Set the values for the storage reference
            discountParamsRef.basePrice = params.basePrice;
            discountParamsRef.strategy = params.strategy;

            /// Access to array of NFTDiscountParams for a specific slicer, product and currency
            NFTDiscountParams[] memory newDiscounts = params.discounts;

            uint256 oldLength = discountParamsRef.discountsArray.length;
            uint256 newLength = newDiscounts.length;
            uint256 maxLength = newLength > oldLength ? newLength : oldLength;

            for (uint256 j; j < maxLength; ) {
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

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /**
    @notice Function called by Slice protocol to calculate current product price.
            Base price is returned if user does not have a discount.

    @param slicerId ID of the slicer being queried
    @param productId ID of the product being queried
    @param currency Currency chosen for the purchase
    @param quantity Number of units purchased
    @param buyer Address of the buyer

    @return ethPrice and currencyPrice of product.
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
        DiscountParams memory params = productParams[slicerId][productId][
            currency
        ];

        /// Based on the strategy, discount represents a value or a %.
        /// If user does not have an NFT, discount will be 0.
        uint256 discount = _getDiscount(params, buyer);

        uint256 price = discount != 0
            ? _getPriceBasedOnStrategy(
                params.strategy,
                params.basePrice,
                discount,
                quantity
            )
            : quantity * params.basePrice;

        // Set ethPrice or currencyPrice based on chosen currency
        if (currency == address(0)) {
            ethPrice = price;
        } else {
            currencyPrice = price;
        }
    }

    //*********************************************************************//
    // ------------------------- internal pures -------------------------- //
    //*********************************************************************//

    /**
    @notice Check if user owns the choosen nft or if the nft address is empty, 
            get the highest discount

    @param params DiscountParams struct
    @param buyer Address of the buyer

    @return discount value
   */
    function _getDiscount(
        DiscountParams memory params,
        address buyer
    ) internal view returns (uint256 discount) {
        /// Loop through all NFTs and get the highest discount
        /// NFTs are sorted from highest to lowest discount, so the first discount found is the highest
        NFTDiscountParams[] memory discountsRef = params.discountsArray;
        for (uint256 i; i < discountsRef.length; ) {
            /// check if user has the amount of NFTs required
            if (
                IERC721(discountsRef[i].nftAddress).balanceOf(buyer) >=
                discountsRef[i].minQuantity
            ) {
                /// get the discount for the nft and break the loop
                discount = discountsRef[i].discount;
                break;
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
    @notice Function called to handle price calculation logic based on strategies

    @param strategy ID of the slicer being queried
    @param basePrice Base price of the product
    @param discount Discount value, can be a value or a %
    @param quantity Number of units purchased

    @return strategyPrice of product.
   */
    function _getPriceBasedOnStrategy(
        Strategy strategy,
        uint256 basePrice,
        uint256 discount,
        uint256 quantity
    ) internal pure returns (uint256 strategyPrice) {
        if (strategy == Strategy.Fixed) {
            strategyPrice = quantity * (basePrice - discount);
        } else if (strategy == Strategy.Percentage) {
            strategyPrice =
                quantity *
                basePrice -
                (quantity * basePrice * discount) /
                100;
        } else {
            strategyPrice = quantity * basePrice;
        }
    }
}
