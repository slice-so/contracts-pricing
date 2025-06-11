// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../../utils/Slice/interfaces/utils/ISliceProductPrice.sol";
import {IProductsModule} from "../../utils/Slice/interfaces/IProductsModule.sol";
import {CurrencyParams} from "./structs/CurrencyParams.sol";
import {ProductDiscounts, DiscountType} from "./structs/ProductDiscounts.sol";
import {DiscountParams, NFTType} from "./structs/DiscountParams.sol";

/**
 * @notice  Slice pricing strategy with discounts based on asset ownership
 * @author  Dom-Mac <@zerohex_eth>
 * @author  jacopo <@jj_ranalli>
 */
abstract contract TieredDiscount is ISliceProductPrice {
    event ProductPriceSet(uint256 slicerId, uint256 productId, CurrencyParams[] params);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotProductOwner();
    error WrongCurrency();
    error InvalidRelativeDiscount();
    error InvalidMinQuantity();
    error DiscountsNotDescending(DiscountParams nft);

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
     * @notice Called by product owner to set base price and discounts for a product.
     *
     * @param slicerId ID of the slicer to set the price params for.
     * @param productId ID of the product to set the price params for.
     * @param params Array of `CurrencyParams` structs
     */
    function setProductPrice(uint256 slicerId, uint256 productId, CurrencyParams[] memory params)
        external
        onlyProductOwner(slicerId, productId)
    {
        _setProductPrice(slicerId, productId, params);
        emit ProductPriceSet(slicerId, productId, params);
    }

    /**
     * @notice Function called by Slice protocol to calculate current product price.
     *
     * @param slicerId ID of the slicer being queried
     * @param productId ID of the product being queried
     * @param currency Currency chosen for the purchase
     * @param quantity Number of units purchased
     * @param buyer Address of the buyer
     * @param params Additional params used to calculate price
     *
     * @return ethPrice and currencyPrice of product.
     */
    function productPrice(
        uint256 slicerId,
        uint256 productId,
        address currency,
        uint256 quantity,
        address buyer,
        bytes memory params
    ) public view override returns (uint256 ethPrice, uint256 currencyPrice) {
        ProductDiscounts memory discountParams = productDiscounts[slicerId][productId][currency];

        if (discountParams.basePrice == 0) {
            if (!discountParams.isFree) revert WrongCurrency();
        } else {
            return _productPrice(slicerId, productId, currency, quantity, buyer, params, discountParams);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _setProductPrice(uint256 slicerId, uint256 productId, CurrencyParams[] memory params) internal virtual;

    function _productPrice(
        uint256 slicerId,
        uint256 productId,
        address currency,
        uint256 quantity,
        address buyer,
        bytes memory params,
        ProductDiscounts memory discountParams
    ) internal view virtual returns (uint256 ethPrice, uint256 currencyPrice);
}
