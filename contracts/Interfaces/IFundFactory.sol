// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IHedgeFund.sol";

interface IFundFactory {
    function createFund(
        address payable _swapRouterContract,
        address payable _eFundToken,
        address payable _fundOwner,
        address payable _eFundPlatform,
        uint256 _fundDuration,
        uint256 _softCap,
        uint256 _hardCap,
        address payable[] calldata allowedTokens,
        HedgeFundInfo calldata _info
    ) external payable returns (address);
}
