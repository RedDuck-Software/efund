// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./IHedgeFund.sol";

interface IHedgeFactory {
    function createFund(uint _fundDurationInMonths) external payable returns(address fundAddress);
}