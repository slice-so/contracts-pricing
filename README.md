# Slice pricing strategies

This repo contains custom pricing strategies for products sold on [Slice](https://slice.so).

Each strategy inherits the [ISliceProductPrice](/src/Slice/interfaces/utils/ISliceProductPrice.sol) interface and serves two main purposes:

- Allow a product owner to set price params for a product via `setProductPrice`;
- Return product price via `productPrice`;

## Strategies

### VRGDA

Variable Rate Gradual Dutch Auctions. Read the [whitepaper here](https://www.paradigm.xyz/2022/08/vrgda).

Slice-specific implementations modified from https://github.com/transmissions11/VRGDAs:

- [Linear VRGDA](/src/VRGDA/LinearVRGDAPrices.sol)
- [Logistic VRGDA](/src/VRGDA/LogisticVRGDAPrices.sol)

### ERC721 Gated Discount

A discount strategy that allows a product owner to set a discount for a product if the buyer owns a specific ERC721 token.

- [ERC721 Gated Discount](/src/ERC721GatedDiscount/ERC721GatedDiscount.sol)

## Contributing

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

TEST4

