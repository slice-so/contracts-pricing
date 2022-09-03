// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IOwnable {
    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function renounceOwnership() external;
}
