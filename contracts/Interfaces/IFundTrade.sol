// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

//import "./IHedgeFund.sol";

interface IFundTrade {

    /// @notice swaps ERC20 token to another ERC20 token
    /// @param tokenFrom address of ERC20 token swap from
    /// @param tokenTo address of ERC20 token swap to
    /// @param amountIn amount of {tokenFrom}
    /// @param amountOutMin minimal amount of {tokenTo} that expected to be received
    function swapERC20ToERC20(address payable tokenFrom, address payable tokenTo, uint256 amountIn, uint256 amountOutMin) external returns (uint256); 
    function swapERC20ToERC20(address payable tokenFrom, address payable tokenTo, uint256 amountIn) external  returns (uint256); 

    function swapERC20ToETH(address payable tokenFrom, uint256 amountIn, uint256 amountOutMin) external  returns (uint256); 
    function swapERC20ToETH(address payable tokenFrom, uint256 amountIn) external  returns (uint256); 

    function swapETHToERC20(address payable tokenTo, uint256 amountIn, uint256 amountOutMin) external  returns (uint256); 
    function swapETHToERC20(address payable tokenTo, uint256 amountIn) external  returns (uint256); 
}