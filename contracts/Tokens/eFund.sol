// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./../SharedImports.sol";

contract eFundERC20 is OZERC20{ 
    constructor() public OZERC20("eFund", "EF"){ 

    }
}