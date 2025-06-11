// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/VRGDA/LinearVRGDAPrices.sol";

contract MockLinearVRGDAPrices is LinearVRGDAPrices {
    constructor(address productsModuleAddress) LinearVRGDAPrices(productsModuleAddress) {}
}
