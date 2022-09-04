// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

interface IAirdropSlices is IERC1155Receiver {
    function isWhitelistSaleStarted() external view returns (bool);

    function whitelistClaimed(address) external;

    function releaseToCollector() external;

    function _closeAirdrop() external;
}
