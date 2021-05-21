// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./IHedgeFund.sol";

interface IFundFactory {
    function createFund(
        address payable swapRouterContract,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external payable returns (address fundAddress);

    function createFundWithEFund(
        uint256 _initialDepositTokens,
        address payable swapRouterContract,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external returns (address fundAddress);
}
