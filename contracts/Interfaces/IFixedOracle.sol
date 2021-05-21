// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IUFundOracle {
    function getPriceInETH(uint256 tokens) external returns (uint256);

    function getPriceInEFund(uint256 eth) external returns (uint256);
}
