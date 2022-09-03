// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IAirdropSlices.sol";

interface IAirdropSlicesStandard is IAirdropSlices {
    function airdropInfo()
        external
        view
        returns (
            bytes32 merkleRoot,
            uint256 whitelistPrice,
            uint256 whitelistStartDate,
            uint256 claimSlicesAmount_
        );

    function claim(bytes32[] calldata proof) external payable;

    function _setParams(
        address collector_,
        bytes32 merkleRoot_,
        uint256 whitelistPrice_,
        uint256 whitelistStartDate_,
        uint256 claimSlicesAmount_
    ) external;
}
