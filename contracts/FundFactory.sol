// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IHedgeFactory.sol";

contract FundFactory is IHedgeFactory {
    uint256 immutable public softCap = 100000000000000000;
    uint256 immutable public hardCap = 100000000000000000000;

    address[] public funds;

    function createFund(uint _fundDurationInMonths) external override payable returns(IHedgeFund fundAddress) { 
        require(msg.value >= softCap && msg.value <= hardCap, "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH");

        HedgeFund newFund = new HedgeFund(address(this), msg.sender, _fundDurationInMonths);
        
        payable(address(newFund)).transfer(msg.value);
        funds.push(address(newFund));

        return newFund;
    }
}