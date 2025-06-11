// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../../utils/Slice/interfaces/utils/ISliceProductPrice.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {IProductsModule} from "../../utils/Slice/interfaces/IProductsModule.sol";

/**
 * @notice  Slice pricing strategy to give one product for free
 * @author  jacopo <@jj_ranalli>
 */
contract OneDiscounted is ISliceProductPrice {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotProductOwner();

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable productsModuleAddress;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Price {
        uint256 usdcPrice;
        address token;
        uint88 tokenId;
        TokenType tokenType;
    }

    enum TokenType {
        ERC721,
        ERC1155
    }

    mapping(uint256 productId => Price price) public usdcPrices;
    mapping(address => bool) public whitelistedAddresses;
    IERC721[] public nfts;

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
     * @param slicerId ID of the slicer to set the price for.
     * @param productId ID of the product to set the price for.
     * @param usdcPrice Price of the product in USDC, with 6 decimals.
     * @param token Address of the token to hold to obtain a free item. Set to address(0) to bypass check.
     * @param tokenId ID of the token to hold to be eligible for discount (only for ERC1155).
     * @param tokenType Type of the token to hold to be eligible for discount - 1 for ERC721, 2 for ERC1155.
     */
    function setProductPrice(
        uint256 slicerId,
        uint256 productId,
        uint256 usdcPrice,
        address token,
        uint88 tokenId,
        TokenType tokenType
    ) external onlyProductOwner(slicerId, productId) {
        usdcPrices[productId] = Price(usdcPrice, token, tokenId, tokenType);
    }

    /**
     * @notice Function called by Slice protocol to calculate current product price.
     * Discount is applied only for first purchase on a slicer.
     *
     * @param productId ID of the product being queried
     * @param quantity Number of units purchased
     * @param buyer Address of the buyer
     *
     * @return ethPrice and currencyPrice of product.
     */
    function productPrice(uint256 slicerId, uint256 productId, address, uint256 quantity, address buyer, bytes memory)
        public
        view
        override
        returns (uint256 ethPrice, uint256 currencyPrice)
    {
        Price memory price = usdcPrices[productId];

        bool isEligible = price.token == address(0);
        if (!isEligible) {
            if (price.tokenType == TokenType.ERC721) {
                isEligible = IERC721(price.token).balanceOf(buyer) != 0;
            } else {
                isEligible = IERC1155(price.token).balanceOf(buyer, price.tokenId) != 0;
            }
        }

        if (isEligible) {
            for (uint256 i = 1; i <= IProductsModule(productsModuleAddress).nextProductId(slicerId); ++i) {
                if (IProductsModule(productsModuleAddress).validatePurchaseUnits(buyer, slicerId, i) != 0) {
                    return (0, usdcPrices[productId].usdcPrice * quantity);
                }
            }

            return (0, usdcPrices[productId].usdcPrice * (quantity - 1));
        }

        return (0, usdcPrices[productId].usdcPrice * quantity);
    }
}
