// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";

struct Price {
    uint128 basePrice;
    uint128 discountedPrice;
}

struct NFT {
    IERC1155 nftAddress;
    uint256 tokenId;
}

contract NFTDiscountFixed is ISliceProductPrice, Ownable {
    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    NFT[] public nfts;
    mapping(uint256 productId => Price price) public usdcPrices;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {
        nfts.push(NFT(IERC1155(0x8876CD7B283b1EeB998aDfeB55a65C51D6b6f693), 1));

        for (uint256 i = 0; i < 46; i++) {
            usdcPrices[i] = Price(14_000_000, 2_000_000);
        }
    }

    /**
     * @notice Called by product owner to set base price and discounts for a product.
     *
     * @param productId ID of the product to set the price params for.
     * @param newPrice New base price for the product.
     */
    function setProductPrice(uint256 productId, Price memory newPrice) external onlyOwner {
        usdcPrices[productId] = newPrice;
    }

    /**
     * @notice Called by product owner to set nfts eligible for free coffee.
     *
     * @param _nfts Array of NFTs to set.
     */
    function setNfts(NFT[] memory _nfts) external onlyOwner {
        for (uint256 i = 0; i < _nfts.length; i++) {
            nfts[i] = _nfts[i];
        }

        for (uint256 i = _nfts.length; i < nfts.length; i++) {
            nfts.pop();
        }
    }

    /**
     * @notice Function called by Slice protocol to calculate current product price.
     *
     * @param productId ID of the product being queried
     * @param quantity Number of units purchased
     * @param buyer Address of the buyer
     *
     * @return ethPrice and currencyPrice of product.
     */
    function productPrice(uint256, uint256 productId, address, uint256 quantity, address buyer, bytes memory)
        public
        view
        override
        returns (uint256 ethPrice, uint256 currencyPrice)
    {
        NFT memory nft;
        for (uint256 i = 0; i < nfts.length; ++i) {
            nft = nfts[i];
            if (nft.nftAddress.balanceOf(buyer, nft.tokenId) != 0) {
                return (0, usdcPrices[productId].discountedPrice * quantity);
            }
        }

        return (0, usdcPrices[productId].basePrice * quantity);
    }
}
