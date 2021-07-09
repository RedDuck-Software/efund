// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

//import "./IHedgeFund.sol";

interface IFundTrade {

    /// @notice swaps ERC20 token to another ERC20 token
    /// @param path trade path
    /// @param amountIn amount of {tokenFrom}
    /// @param amountOutMin minimal amount of {tokenTo} that expected to be received
    function swapERC20ToERC20(address[] calldata path, uint256 amountIn, uint256 amountOutMin) external returns (uint256); 
    function swapERC20ToETH(address payable tokenFrom, uint256 amountIn, uint256 amountOutMin) external  returns (uint256); 
    function swapETHToERC20(address payable tokenTo, uint256 amountIn, uint256 amountOutMin) external  returns (uint256); 
}