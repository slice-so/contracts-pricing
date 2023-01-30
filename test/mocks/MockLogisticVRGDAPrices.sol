// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "src/VRGDA/LogisticVRGDAPrices.sol";

contract MockLogisticVRGDAPrices is LogisticVRGDAPrices {
  constructor(address productsModuleAddress)
    LogisticVRGDAPrices(productsModuleAddress)
  {}
}
