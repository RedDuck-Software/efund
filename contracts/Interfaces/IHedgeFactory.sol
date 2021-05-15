// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "IHedgeFund.sol";

interface IHedgeFactory {
    function createFund() external override payable returns(IHedgeFund fundAddress);
}