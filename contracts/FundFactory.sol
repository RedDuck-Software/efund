// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6; // because of uniswap

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IHedgeFactory.sol";

contract FundFactory is IHedgeFactory {
    uint256 immutable public softCap = 100000000000000000;
    uint256 immutable public hardCap = 100000000000000000000;

    address[] public funds;

    function createFund(uint _fundDurationInMonths) external payable override returns(address fundAddress) { 
       require(msg.value >= softCap && msg.value <= hardCap, "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH");

        HedgeFund newFund = new HedgeFund(softCap, hardCap, msg.sender, _fundDurationInMonths);
        
        _sendEth(payable(address(newFund)), msg.value);

        funds.push(address(newFund));

        return address(newFund);
    }

    // todo: ask guys in chats
    function _sendEth(address payable _to, uint256 _value) private  returns (bool){
        (bool sent, ) = _to.call{value: _value}("");
        require(sent, "could not send ether to the fund");
    }
}