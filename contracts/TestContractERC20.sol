// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";

import {
    ERC20 as OZERC20,
    IERC20 as OZIERC20
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface HedgeFundContractInterface {
    function testGetAmountsIn(address[] calldata path, uint256 amountOut)
        external
        view
        returns (uint256[] memory);

    function testGetAmountsOut(address[] calldata path, uint256 amountIn)
        external
        view
        returns (uint256[] memory);

    function getWETH() external view returns (address);

    function getUniswapAddress() external view returns (address payable);

    function makeDepositETH() external payable;

    function makeDepositERC20(address contractAddress, uint256 amount) external;

    function makeDepositInDefaultToken(uint256 amount) external;
}

contract HedgeFundContractERC20 is OZERC20, TestContractInterface {
    UniswapV2Router02 private router;

    DepositInfo[] public deposits;

    address payable private uniswapv2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public immutable withdrawPeroid = 60 * 60 * 24 * 10; // ten days

    uint256 public immutable minimalDepositAmountInWEI =
        1000000000000000000 / 2;

    uint256 public immutable depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    address public defalutDepositTokenAddress;

    uint256 public lastWidthrow;

    constructor(address _defaultDepositTokenAddress)
        public
        OZERC20("hedge", "hg")
    {
        router = UniswapV2Router02(uniswapv2RouterAddress);
        defalutDepositTokenAddress = _defaultDepositTokenAddress;
    }

    function testGetAmountsIn(address[] calldata path, uint256 amountOut)
        external
        view
        override
        returns (uint256[] memory)
    {
        return router.getAmountsIn(amountOut, path);
    }

    function testGetAmountsOut(address[] calldata path, uint256 amountIn)
        external
        view
        override
        returns (uint256[] memory)
    {
        return router.getAmountsOut(amountIn, path);
    }

    function getWETH() external view override returns (address) {
        return router.WETH();
    }

    function getUniswapAddress()
        external
        view
        override
        returns (address payable)
    {
        return uniswapv2RouterAddress;
    }

    function makeDepositInDefaultToken(uint256 amount) external override {
        OZIERC20 token = OZERC20(defalutDepositTokenAddress);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        token.transferFrom(msg.sender, address(this), amount);
    }

    function makeDepositERC20(address contractAddress, uint256 amount)
        external
        override
    {
        address[] memory path = new address[](2);

        path[0] = contractAddress;
        path[1] = defalutDepositTokenAddress;

        // how much [defaultDepositToken] we can buy with [contractAddress] token
        uint256 amountOut = router.getAmountsOut(amount, path)[1];

        uint256[] memory amounts =
            router.swapExactTokensForTokens(
                amount,
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        DepositInfo memory deposit =
            DepositInfo(msg.sender, amounts[1], address(0), false);

        deposits.push(deposit);
    }

    function makeDepositETH() external payable override {
        require(
            msg.value > minimalDepositAmountInWEI,
            "Transaction value is less then minimum deposit amout"
        );

        address[] memory path = new address[](2);

        path[0] = this.getWETH();
        path[0] = defalutDepositTokenAddress;

        uint256 amountOut = router.getAmountsOut(msg.value, path)[1];

        uint256[] memory amounts =
            router.swapExactETHForTokens(
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        DepositInfo memory deposit =
            DepositInfo(msg.sender, amounts[1], address(0), false);

        deposits.push(deposit);
    }

    struct DepositInfo {
        address depositOwner;
        uint256 depositAmount; // deposit amount in WETH
        address depositContractAddress; // address of the erc20 token, from which deposit was made. 0 - if deposit in ETH
        bool isWithdrawed;
    }
}
