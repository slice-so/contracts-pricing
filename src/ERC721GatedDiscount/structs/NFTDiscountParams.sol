// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @param nft                  NFT address
/// @param discount             discount amount
/// @param minQuantity          minimum quantity of NFTs owned to get the discount
struct NFTDiscountParams {
    IERC721 nft;
    uint256 discount;
    uint256 minQuantity;
}
