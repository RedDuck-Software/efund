// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol"
import "";


contract FundFactory  {
    uint256 immutable public softCap = 100000000000000000;

    uint256 immutable public hardCap = 100000000000000000000;


    bool public isOpen;

    function createFund() public payable returns() { 

    }
}