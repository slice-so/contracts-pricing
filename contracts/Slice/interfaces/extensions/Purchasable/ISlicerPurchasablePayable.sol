// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./ISlicerPurchasable.sol";

interface ISlicerPurchasablePayable is ISlicerPurchasable {
    /// @notice Releases the ETH balance of this contract to the specified `_collector`.
    function releaseToCollector() external;
}
