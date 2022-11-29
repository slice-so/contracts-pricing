// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
import "lib/forge-std/src/Test.sol";
import "src/AdditionalPrice/AdditionalPrice.sol";
import "src/AdditionalPrice/structs/CurrenciesParams.sol";
import "src/AdditionalPrice/structs/CurrencyAdditionalParams.sol";
import {MockProductsModule} from "./mocks/MockProductsModule.sol";

uint256 constant slicerId = 0;
uint256 constant productId = 1;

contract TestAdditionalPrice is Test {
    MockProductsModule productsModule;
    AdditionalPrice additionalPrice;
    address eth = address(0);
    uint256 basePrice = 1000;
    uint256 inputOneAddAmount = 100;
    uint256 inputTwoAddAmount = 200;
    uint256 inputOnePercentage = 10;
    uint256 inputTwoPercentage = 20;

    function createPriceStrategy(
        Strategy _strategy,
        bool _dependsOnQuantity
    ) public {
        CurrencyAdditionalParams[]
            memory _currencyAdditionalParams = new CurrencyAdditionalParams[](
                2
            );

        /// set product price with additional custom inputs
        _currencyAdditionalParams[0] = CurrencyAdditionalParams(
            1,
            _strategy == Strategy.Custom
                ? inputOneAddAmount
                : inputOnePercentage
        );
        _currencyAdditionalParams[1] = CurrencyAdditionalParams(
            2,
            _strategy == Strategy.Custom
                ? inputTwoAddAmount
                : inputTwoPercentage
        );

        CurrenciesParams[] memory currenciesParams = new CurrenciesParams[](1);
        currenciesParams[0] = CurrenciesParams(
            eth,
            basePrice,
            _strategy,
            _dependsOnQuantity,
            _currencyAdditionalParams
        );
        additionalPrice.setProductPrice(slicerId, productId, currenciesParams);
    }

    function setUp() public {
        productsModule = new MockProductsModule();
        additionalPrice = new AdditionalPrice(address(productsModule));
    }

    /// @notice quantity is uint128, uint256 causes overflow error
    function testProductPriceEth(uint128 _quantity) public {
        createPriceStrategy(Strategy.Custom, false);
        uint256 _choosenId = 1;
        bytes memory customInputId = abi.encodePacked(_choosenId);

        (uint256 ethPrice, uint256 currencyPrice) = additionalPrice
            .productPrice(
                slicerId,
                productId,
                eth,
                _quantity,
                address(1),
                customInputId
            );

        assertEq(currencyPrice, 0);
        assertEq(ethPrice, _quantity * basePrice + inputOneAddAmount);
    }

    /// @notice quantity is uint128, uint256 causes overflow error
    /// @dev if customInput = 0 -> the base price is returned
    function testProductBasePriceEth(uint128 _quantity) public {
        createPriceStrategy(Strategy.Custom, false);
        uint256 _choosenId = 0;
        bytes memory customInputId = abi.encodePacked(_choosenId);

        (uint256 ethPrice, uint256 currencyPrice) = additionalPrice
            .productPrice(
                slicerId,
                productId,
                eth,
                _quantity,
                address(1),
                customInputId
            );

        assertEq(currencyPrice, 0);
        assertEq(ethPrice, _quantity * basePrice);
    }

    /// @dev non existing input returns the base price, quantity = 1
    function testNonExistingInput() public {
        createPriceStrategy(Strategy.Custom, false);
        uint256 _choosenId = 10;
        bytes memory customInputId = abi.encodePacked(_choosenId);

        (uint256 ethPrice, uint256 currencyPrice) = additionalPrice
            .productPrice(
                slicerId,
                productId,
                eth,
                1,
                address(1),
                customInputId
            );

        assertEq(currencyPrice, 0);
        assertEq(ethPrice, basePrice);
    }

    /// @dev Input 1: 10%, input 2: 20%
    function testPercentageStrategy() public {
        createPriceStrategy(Strategy.Percentage, false);
        bytes memory customInputIdOne = abi.encodePacked(uint(1));
        bytes memory customInputIdTwo = abi.encodePacked(uint(2));
        uint256 quantity = 10;
        (uint256 ethPrice, uint256 currencyPrice) = additionalPrice
            .productPrice(
                slicerId,
                productId,
                eth,
                quantity,
                address(1),
                customInputIdOne
            );
        (uint256 ethPriceTwo, ) = additionalPrice.productPrice(
            slicerId,
            productId,
            eth,
            quantity,
            address(1),
            customInputIdTwo
        );

        assertEq(currencyPrice, 0);
        assertEq(
            ethPrice,
            quantity * basePrice + (basePrice * inputOnePercentage) / 100
        );
        assertEq(
            ethPriceTwo,
            quantity * basePrice + (basePrice * inputTwoPercentage) / 100
        );
    }

    /// @dev Input 1: 10%, input 2: 20%
    function testPercentageQuantity() public {
        createPriceStrategy(Strategy.Percentage, true);
        bytes memory customInputIdOne = abi.encodePacked(uint(1));
        bytes memory customInputIdTwo = abi.encodePacked(uint(2));
        uint256 quantity = 2;
        (uint256 ethPrice, uint256 currencyPrice) = additionalPrice
            .productPrice(
                slicerId,
                productId,
                eth,
                quantity,
                address(1),
                customInputIdOne
            );
        (uint256 ethPriceTwo, ) = additionalPrice.productPrice(
            slicerId,
            productId,
            eth,
            quantity,
            address(1),
            customInputIdTwo
        );

        assertEq(currencyPrice, 0);
        assertEq(
            ethPrice,
            quantity *
                basePrice +
                (quantity * basePrice * inputOnePercentage) /
                100
        );
        assertEq(
            ethPriceTwo,
            quantity *
                basePrice +
                (quantity * basePrice * inputTwoPercentage) /
                100
        );
    }

    /// @dev Input 1: 10%, input 2: 20%
    function testAddQuantity() public {
        createPriceStrategy(Strategy.Custom, true);
        bytes memory customInputIdOne = abi.encodePacked(uint(1));
        bytes memory customInputIdTwo = abi.encodePacked(uint(2));
        uint256 quantity = 2;
        (uint256 ethPrice, uint256 currencyPrice) = additionalPrice
            .productPrice(
                slicerId,
                productId,
                eth,
                quantity,
                address(1),
                customInputIdOne
            );
        (uint256 ethPriceTwo, ) = additionalPrice.productPrice(
            slicerId,
            productId,
            eth,
            quantity,
            address(1),
            customInputIdTwo
        );

        assertEq(currencyPrice, 0);
        assertEq(ethPrice, quantity * (basePrice + inputOneAddAmount));
        assertEq(ethPriceTwo, quantity * (basePrice + inputTwoAddAmount));
    }
}
