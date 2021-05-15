// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IHedgeFund {
 
    function getWETH() external view returns (address);

    function makeDepositInETH() external payable;

    function makeDepositInERC20(address contractAddress, uint256 amount) external;

    function makeDepositInDefaultToken(uint256 amount) external;

    function withdraw() external;
}