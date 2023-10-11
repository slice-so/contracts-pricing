// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFriendTechShares {
    function sharesBalance(address sharesSubject, address holder) external view returns (uint256);

    function buyShares(address sharesSubject, uint256 amount) external payable;

    function sellShares(address sharesSubject, uint256 amount) external payable;
}
