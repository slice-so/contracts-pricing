// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum NFTType {
    ERC721,
    ERC1155
}

/// @param nft                  address to check ownership against
/// @param discount             discount amount, based on `discountType`
///                             if `discountType` is `Relative`, discount is less than 1e4
/// @param minQuantity          minimum quantity of assets owned to get the discount
/// @param nftType              type of NFT, can be `ERC721` or `ERC1155`
/// @param tokenId              id of the ERC1155 NFT to check ownership against
struct DiscountParams {
    address nft;
    uint80 discount;
    uint8 minQuantity;
    NFTType nftType;
    uint256 tokenId;
}
