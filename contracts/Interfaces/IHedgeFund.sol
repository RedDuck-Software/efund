// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IHedgeFund {
 
    function getWETH() external view returns (address);

    function makeDepositInETH() external payable;

    function withdraw() external;

    function widthrawBeforeFundStarted() external;

    function setFundStatusActive() external;

    function setFundStatusCompleted() external;

    function setFundStatusClosed() external;

    function getEndTime() external view returns (uint256);

    function getCurrentBalanceInETH() external view returns (uint256);
}