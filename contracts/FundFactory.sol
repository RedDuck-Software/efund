// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol"
import "./HedgeFund.sol";


contract FundFactory  {
    uint256 immutable public softCap = 100000000000000000;

    function createFund() public payable returns(HedgeFund fundAddress) { 
        require(msg.value >= softCap && msg.value <= hardCap, "To create fund you need to send minimum 0.1 ETH");
        HedgeFund newFund = new HedgeFund(msg.sender);
        newFund.transfer(msg.value);
        return newFund;
    }
}