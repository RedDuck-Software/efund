// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6;

struct HedgeFundInfo {
    address payable swapRouterContract;
    address payable eFundTokenContract;
    address payable eFundPlatform;
    uint256 softCap;
    uint256 hardCap;
    uint256 managerFee;
    uint256 minimalDepostitAmount;
    uint256 minTimeUntilFundStart;
    address payable managerAddress;
    uint256 duration;
    address payable[] allowedTokenAddresses;
}