// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IHedgeFund {
 
    function getWETH() external view returns (address);

    function makeDepositInETH() external payable;

    function withdraw() external;
}