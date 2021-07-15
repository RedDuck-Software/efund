// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

struct HedgeFundInfo {
    string name;
    string description;
}

interface IHedgeFund {
    function getWETH() external view returns (address);

    function makeDeposit() external payable;

    function withdraw() external;

    function withdrawBeforeFundStarted() external;

    function setFundStatusActive() external;

    function setFundStatusCompleted() external;

    function setFundStatusClosed() external;

    function getEndTime() external view returns (uint256);

    function getCurrentBalanceInWei() external view returns (uint256);

    function withdrawToManager() external;
}
