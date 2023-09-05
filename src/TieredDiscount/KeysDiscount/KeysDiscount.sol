// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {
    CurrencyParams,
    DiscountParams,
    ProductDiscounts,
    DiscountType,
    ERC721Discount
} from "../ERC721Discount/ERC721Discount.sol";
import {IFriendTechShares} from "./interfaces/IFriendTechShares.sol";

/**
 * @title   KeysDiscount - Slice pricing strategy with discounts based on Friend Tech keys ownership
 * @author  Dom-Mac <@zerohex_eth>
 * @author  jacopo <@jj_ranalli>
 */

contract KeysDiscount is ERC721Discount {
    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    IFriendTechShares public constant friendTechShares = IFriendTechShares(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _productsModuleAddress) ERC721Discount(_productsModuleAddress) {}

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the highest discount available for a user, based on owned keys.
     *
     * @param discountParams `ProductDiscounts` struct
     * @param buyer Address of the buyer
     *
     * @return Discount value
     */
    function _getHighestDiscount(ProductDiscounts memory discountParams, address buyer)
        internal
        view
        override
        returns (uint256)
    {
        DiscountParams[] memory discounts = discountParams.discountsArray;
        uint256 length = discounts.length;
        DiscountParams memory el;

        address prevAsset;
        uint256 keysBalance;
        for (uint256 i; i < length;) {
            el = discounts[i];

            // Skip retrieving balance if asset is the same as previous iteration
            if (prevAsset != el.nft) {
                keysBalance = friendTechShares.sharesBalance(el.nft, buyer);
            }

            // Check if user has at enough keys to qualify for the discount
            if (keysBalance >= el.minQuantity) {
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
}
