// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ISlicer.sol";

interface IFundsModule {
    function depositEth(address account, uint256 protocolPayment) external payable;

    function depositTokenFromSlicer(
        uint256 tokenId,
        address account,
        address currency,
        uint256 amount,
        uint256 protocolPayment
    ) external;

    function withdraw(address account, address currency) external;

    function batchWithdraw(address account, address[] memory currencies) external;

    function withdrawOnRelease(
        uint256 tokenId,
        address account,
        address currency,
        uint256 amount,
        uint256 protocolPayment
    ) external payable;

    function batchReleaseSlicers(
        ISlicer[] memory slicers,
        address account,
        address currency,
        bool triggerWithdraw
    ) external;

    function balance(address account, address currency)
        external
        view
        returns (uint256 accountBalance, uint256 protocolPayment);
}
