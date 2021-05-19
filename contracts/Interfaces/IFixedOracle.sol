// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;


interface IUFundOracle { 
    function getPriceInETH() external returns (uint256);
}