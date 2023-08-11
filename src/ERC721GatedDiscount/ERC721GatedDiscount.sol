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
    function setProductPrice(
        uint256 slicerId,
        uint256 productId,
        CurrenciesParams[] memory currenciesParams
    ) external onlyProductOwner(slicerId, productId) {
        /// Add reference for currency used in loop
        NFTDiscountParams[] memory discountsRef;

        /// For each strategy, grouped by currency
        for (uint256 i; i < currenciesParams.length; ) {
            /// Access to DiscountParams for a specific slicer, product and currency
            DiscountParams storage params = productParams[slicerId][productId][
                currenciesParams[i].currency
            ];

            /// Save currency base price and strategy values
            params.basePrice = currenciesParams[i].basePrice;
            params.strategy = currenciesParams[i].strategy;
            params.dependsOnQuantity = currenciesParams[i].dependsOnQuantity;

            /// Store reference for currency used in loop
            discountsRef = currenciesParams[i].discounts;
            /// Set discount values for each nft in the mapping
            for (uint256 j; j < discountsRef.length; ) {
                /// Save the discount value for the j input
                params.nftDiscounts[discountsRef[j].nftAddress] = discountsRef[
                    j
                ].discount;

                unchecked {
                    ++j;
                }
            }

            /// Set discounts array
            params.nftDiscountsArray = discountsRef;

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
    @param data Data passed to the function by the caller. In this case, the address of the NFT.

    @return ethPrice and currencyPrice of product.
   */
    function productPrice(
        uint256 slicerId,
        uint256 productId,
        address currency,
        uint256 quantity,
        address buyer,
        bytes memory data
    ) public view override returns (uint256 ethPrice, uint256 currencyPrice) {
        /// get basePrice, strategy and dependsOnQuantity from storage
        uint256 basePrice = productParams[slicerId][productId][currency]
            .basePrice;
        Strategy strategy = productParams[slicerId][productId][currency]
            .strategy;
        bool dependsOnQuantity = productParams[slicerId][productId][currency]
            .dependsOnQuantity;

        /// based on the strategy, discount represents a value or a %
        /// if user does not have an NFT, discount will be 0
        uint256 discount = _getDiscount(
            productParams[slicerId][productId][currency],
            buyer,
            data
        );

        uint256 price = discount != 0
            ? _getPriceBasedOnStrategy(
                strategy,
                dependsOnQuantity,
                basePrice,
                discount,
                quantity
            )
            : quantity * basePrice;

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
    @param data Data passed to the function by the caller. In this case, the address of the NFT.

    @return discount value
   */
    function _getDiscount(
        DiscountParams storage params,
        address buyer,
        bytes memory data
    ) internal view returns (uint256 discount) {
        /// If the address of the NFT is not empty, check if user has the NFT and get the discount for that NFT
        if (data.length != 0) {
            /// decode the address of the nft from byte to address
            address nftAddress = abi.decode(data, (address));
            /// check if user has the nft
            if (IERC721(nftAddress).balanceOf(buyer) > 0) {
                /// get the discount for the nft
                discount = params.nftDiscounts[nftAddress];
            }
        } else {
            /// If the address of the NFT is empty, loop through all NFTs and get the highest discount
            /// NFTs are sorted from highest to lowest discount, so the first discount found is the highest
            NFTDiscountParams[] memory discountsRef = params.nftDiscountsArray;
            for (uint256 i; i < discountsRef.length; ) {
                /// check if user has the nft
                if (IERC721(discountsRef[i].nftAddress).balanceOf(buyer) > 0) {
                    /// get the discount for the nft and break the loop
                    discount = discountsRef[i].discount;
                    break;
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
    @notice Function called to handle price calculation logic based on strategies

    @param strategy ID of the slicer being queried
    @param dependsOnQuantity ID of the product being queried
    @param basePrice Base price of the product
    @param discount Discount value, can be a value or a %
    @param quantity Number of units purchased

    @return strategyPrice of product.
   */
    function _getPriceBasedOnStrategy(
        Strategy strategy,
        bool dependsOnQuantity,
        uint256 basePrice,
        uint256 discount,
        uint256 quantity
    ) internal pure returns (uint256 strategyPrice) {
        if (strategy == Strategy.Fixed) {
            strategyPrice = dependsOnQuantity
                ? quantity * (basePrice - discount)
                : quantity * basePrice - discount;
        } else if (strategy == Strategy.Percentage) {
            strategyPrice = dependsOnQuantity
                ? quantity * basePrice - (quantity * basePrice * discount) / 100
                : quantity * basePrice - (basePrice * discount) / 100;
        } else {
            strategyPrice = quantity * basePrice;
        }
    }
}
