// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import {IProductsModule} from "../Slice/interfaces/IProductsModule.sol";
import {DiscountParams, Strategy} from "./structs/DiscountParams.sol";
import {CurrenciesParams} from "./structs/CurrenciesParams.sol";
import {NFTDiscountParams} from "./structs/NFTDiscountParams.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title    NFT gated discount - Slice pricing strategy
 *   @author   Dom-Mac <@zerohex_eth>
 *   @author   jacopo.eth
 *   @notice   Discount product prices based on NFT ownership
 */

contract ERC721GatedDiscount is ISliceProductPrice {
    //*********************************************************************//
    // ------------------------ immutable storage ------------------------ //
    //*********************************************************************//

    address public immutable productsModuleAddress;

    //*********************************************************************//
    // ------------------------- mutable storage ------------------------- //
    //*********************************************************************//

    mapping(uint256 slicerId => mapping(uint256 productId => mapping(address currency => DiscountParams))) public
        productParams;

    mapping(
        uint256 slicerId
            => mapping(uint256 productId => mapping(address currency => mapping(address nftAddress => uint256)))
    ) public nftDiscounts;

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
     * @notice Check if msg.sender is owner of a product. Used to manage access of `setProductPrice`
     *         in implementations of this contract.
     */
    modifier onlyProductOwner(uint256 slicerId, uint256 productId) {
        require(
            IProductsModule(productsModuleAddress).isProductOwner(slicerId, productId, msg.sender), "NOT_PRODUCT_OWNER"
        );
        _;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /**
     * @notice Set NFTs and related discount for product.
     *
     * @param slicerId ID of the slicer to set the price params for.
     * @param productId ID of the product to set the price params for.
     * @param currenciesParams Array of `CurrenciesParams` structs,
     *                         remeber to pass discounts sorted from highest to lowest
     */
    function setProductPrice(uint256 slicerId, uint256 productId, CurrenciesParams[] memory currenciesParams)
        external
        onlyProductOwner(slicerId, productId)
    {
        /// For each strategy, grouped by currency
        for (uint256 i; i < currenciesParams.length;) {
            /// Ref of `CurrenciesParams` struct
            CurrenciesParams memory params = currenciesParams[i];

            // Initialize the storage reference for the nftDiscountsArray
            DiscountParams storage discountParamsRef = productParams[slicerId][productId][params.currency];

            // Set the values for the storage reference
            discountParamsRef.basePrice = params.basePrice;
            discountParamsRef.strategy = params.strategy;
            discountParamsRef.dependsOnQuantity = params.dependsOnQuantity;

            /// Access to array of NFTDiscountParams for a specific slicer, product and currency
            NFTDiscountParams[] memory discountsRef = params.discounts;

            for (uint256 j; j < discountsRef.length;) {
                /// Set discount values for each nft in the nftDiscounts mapping
                nftDiscounts[slicerId][productId][currenciesParams[i].currency][discountsRef[j].nftAddress] =
                    discountsRef[j].discount;

                /// Manually copy each element from memory to storage on DiscountParams
                discountParamsRef.nftDiscountsArray.push(discountsRef[j]);

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
     * @notice Function called by Slice protocol to calculate current product price.
     *         Base price is returned if user does not have a discount.
     *
     * @param slicerId ID of the slicer being queried
     * @param productId ID of the product being queried
     * @param currency Currency chosen for the purchase
     * @param quantity Number of units purchased
     * @param buyer Address of the buyer
     * @param data Data passed to the function by the caller. In this case, the address of the NFT.
     *
     * @return ethPrice and currencyPrice of product.
     */
    function productPrice(
        uint256 slicerId,
        uint256 productId,
        address currency,
        uint256 quantity,
        address buyer,
        bytes memory data
    ) public view override returns (uint256 ethPrice, uint256 currencyPrice) {
        /// Access to DiscountParams for a specific slicer, product and currency
        DiscountParams memory params = productParams[slicerId][productId][currency];

        /// Based on the strategy, discount represents a value or a %.
        /// If user does not have an NFT, discount will be 0.
        uint256 discount = _getDiscount(params, slicerId, productId, currency, buyer, data);

        uint256 price = discount != 0
            ? _getPriceBasedOnStrategy(params.strategy, params.dependsOnQuantity, params.basePrice, discount, quantity)
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
     * @notice Check if user owns the choosen nft or if the nft address is empty,
     *         get the highest discount
     *
     * @param params DiscountParams struct
     * @param buyer Address of the buyer
     * @param data Data passed to the function by the caller. In this case, the address of the NFT.
     *
     * @return discount value
     */
    function _getDiscount(
        DiscountParams memory params,
        uint256 slicerId,
        uint256 productId,
        address currency,
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
                discount = nftDiscounts[slicerId][productId][currency][nftAddress];
            }
        } else {
            /// If the address of the NFT is empty, loop through all NFTs and get the highest discount
            /// NFTs are sorted from highest to lowest discount, so the first discount found is the highest
            NFTDiscountParams[] memory discountsRef = params.nftDiscountsArray;
            for (uint256 i; i < discountsRef.length;) {
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
     * @notice Function called to handle price calculation logic based on strategies
     *
     * @param strategy ID of the slicer being queried
     * @param dependsOnQuantity ID of the product being queried
     * @param basePrice Base price of the product
     * @param discount Discount value, can be a value or a %
     * @param quantity Number of units purchased
     *
     * @return strategyPrice of product.
     */
    function _getPriceBasedOnStrategy(
        Strategy strategy,
        bool dependsOnQuantity,
        uint256 basePrice,
        uint256 discount,
        uint256 quantity
    ) internal pure returns (uint256 strategyPrice) {
        if (strategy == Strategy.Fixed) {
            strategyPrice = dependsOnQuantity ? quantity * (basePrice - discount) : quantity * basePrice - discount;
        } else if (strategy == Strategy.Percentage) {
            strategyPrice = dependsOnQuantity
                ? quantity * basePrice - (quantity * basePrice * discount) / 100
                : quantity * basePrice - (basePrice * discount) / 100;
        } else {
            strategyPrice = quantity * basePrice;
        }
    }
}
