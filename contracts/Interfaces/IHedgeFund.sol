// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IHedgeFund {
    function makeDeposit() external payable;

    function withdrawDeposits() external;

    function withdrawBeforeFundStarted() external;

    function setFundStatusActive() external;

    function setFundStatusCompleted() external;

    function setFundStatusClosed() external;

    function getEndTime() external view returns (uint256);

    function withdrawToManager() external;
}
