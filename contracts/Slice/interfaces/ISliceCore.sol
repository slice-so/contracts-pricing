// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../structs/SliceParams.sol";
import "./utils/IOwnable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

interface ISliceCore is IOwnable, IERC1155Upgradeable, IERC2981Upgradeable {
    function slice(SliceParams calldata params) external;

    function reslice(
        uint256 tokenId,
        address payable[] calldata accounts,
        int32[] calldata tokensDiffs
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external override;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external override;

    function slicerBatchTransfer(
        address from,
        address[] memory recipients,
        uint256 id,
        uint256[] memory amounts,
        bool release
    ) external;

    function safeTransferFromUnreleased(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function setController(uint256 id, address newController) external;

    function setRoyalty(
        uint256 tokenId,
        bool isSlicer,
        bool isActive,
        uint256 royaltyPercentage
    ) external;

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount);

    function slicers(uint256 id) external view returns (address);

    function controller(uint256 id) external view returns (address);

    function totalSupply(uint256 id) external view returns (uint256);

    function supply() external view returns (uint256);

    function exists(uint256 id) external view returns (bool);

    function _setBasePath(string calldata basePath_) external;

    function _togglePause() external;
}
