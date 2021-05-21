// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./BEP20.sol";

contract eFundBEP20 is BEP20{ 
    constructor() public BEP20("eFund", "EF"){ 
        _mint(msg.sender, 10**18);
    }
}