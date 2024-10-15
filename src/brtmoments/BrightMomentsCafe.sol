// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISliceProductPrice} from "../Slice/interfaces/utils/ISliceProductPrice.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IProductsModule} from "../Slice/interfaces/IProductsModule.sol";

/**
 * @notice  Slice pricing strategy for bright moments
 * @author  jacopo <@jj_ranalli>
 * @author  Dom-Mac <@zerohex_eth>
 */
contract BrightMomentsCafe is ISliceProductPrice, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotProductOwner();

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable productsModuleAddress;
    uint256 public constant BRTMOMENTSCAFE_STOREID = 298;
    uint256 internal constant MAX_PRODUCTID = 8;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 productId => uint256 price) public usdcPrices;
    mapping(address => bool) public whitelistedAddresses;
    IERC721[] public nfts;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _productsModuleAddress) {
        productsModuleAddress = _productsModuleAddress;

        usdcPrices[1] = 5400000;
        usdcPrices[2] = 5400000;
        usdcPrices[3] = 5400000;
        usdcPrices[4] = 5400000;
        usdcPrices[5] = 5400000;
        usdcPrices[6] = 5400000;
        usdcPrices[7] = 3250000; // tea
        usdcPrices[8] = 2150000; // water
        usdcPrices[9] = 10800000; // air
        usdcPrices[10] = 54000000; // quarterly
        usdcPrices[11] = 215000000; // ledger
        usdcPrices[12] = 86500000; // hoodie
        usdcPrices[13] = 48500000; // shirt
        usdcPrices[14] = 48500000; // shirt
        usdcPrices[15] = 21500000; // tote

        whitelistedAddresses[0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF] = true;
        whitelistedAddresses[0xf4140f2721f5Fd76eA2A3b6864ab49e0fBa1f7d0] = true;
        whitelistedAddresses[0x396D8177e5E1b9cAfb89692261f6c647Aa77f00C] = true;

        nfts.push(IERC721(0xFc30e5Ab92b78928634B4F7C6000F80d700bcE56));
        nfts.push(IERC721(0x55E8749AA336D30DF466078B9535cd97b5024dcf));
        nfts.push(IERC721(0x36FcD1b2CA01aD91D0a0680B4EAc21149F2a98Bb));
        nfts.push(IERC721(0x9D19D7F02AD521A377AafD331cCFF8162Fc52959));
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Called by product owner to set base price and discounts for a product.
     *
     * @param productId ID of the product to set the price params for.
     * @param newPrice New base price for the product.
     */
    function setProductPrice(uint256 productId, uint256 newPrice) external onlyOwner {
        usdcPrices[productId] = newPrice;
    }

    /**
     * @notice Called by product owner to set base price and discounts for a product.
     *
     * @param addr Address to set as whitelisted or not.
     * @param isWhitelisted Whether to whitelist or not.
     */
    function setWhitelistedAddress(address addr, bool isWhitelisted) external onlyOwner {
        whitelistedAddresses[addr] = isWhitelisted;
    }

    /**
     * @notice Called by product owner to set nfts eligible for free coffee.
     *
     * @param _nfts Array of NFTs to set.
     */
    function setNfts(IERC721[] calldata _nfts) external onlyOwner {
        nfts = _nfts;
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
        if (whitelistedAddresses[buyer]) {
            return (0, 0);
        }

        if (productId <= MAX_PRODUCTID) {
            for (uint256 i = 0; i < nfts.length; ++i) {
                if (nfts[i].balanceOf(buyer) != 0) {
                    for (uint256 k = 1; k <= MAX_PRODUCTID; ++k) {
                        if (
                            IProductsModule(productsModuleAddress).validatePurchaseUnits(
                                buyer, BRTMOMENTSCAFE_STOREID, k
                            ) != 0
                        ) {
                            return (0, usdcPrices[productId] * quantity);
                        }
                    }

                    return (0, usdcPrices[productId] * (quantity - 1));
                }
            }
        }

        return (0, usdcPrices[productId] * quantity);
    }
}
