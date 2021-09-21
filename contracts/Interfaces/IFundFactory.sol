// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6;

import "./IHedgeFund.sol";
import "../Types/HedgeFundInfo.sol";

interface IFundFactory {
    function createFund(HedgeFundInfo calldata _hedgeFundInfo) external payable returns (address) ;
}
