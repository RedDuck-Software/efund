// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IHedgeFund {
    function makeDeposit() external payable;

    function withdrawDeposits() external;

    function withdrawDepositsBeforeFundStarted() external;

    function setFundStatusActive() external;

    function setFundStatusCompleted() external;

    function getEndTime() external view returns (uint256);

    function withdrawManagerProfit() external;
}
