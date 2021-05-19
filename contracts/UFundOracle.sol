// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./Interfaces/IFixedOracle.sol"

contract UFundOracle is IUFundOracle {

    uint256 public priceInEther = 1;

    function getPriceInETH(uint256 tokens) external override returns (uint256){
        return tokens * priceInEther;
    }
}
