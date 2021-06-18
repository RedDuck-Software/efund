// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./IHedgeFund.sol";

interface IFundFactory {
    function createFund(
        address payable _swapRouterContract,
        address payable _eFundToken,
        address payable _fundOwner,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external payable returns (address) {
}
