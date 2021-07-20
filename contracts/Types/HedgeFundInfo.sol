// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6;

struct HedgeFundInfo {
    address payable _swapRouterContract;
    address payable _eFundTokenContract;
    address payable _eFundPlatform;
    uint256 _softCap;
    uint256 _hardCap;
    uint256 managerFee;
    uint256 minimalDepostitAmount;
    uint256 minTimeUntilFundStart;
    address payable _managerAddress;
    uint256 _duration;
    address payable[] _allowedTokenAddresses;
}