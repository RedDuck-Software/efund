// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IHedgeFund {
    function getWETH() external view returns (address);

    function makeDeposit(uint256 amount) external;

    function withdraw() external;

    function withdrawBeforeFundStarted() external;

    function setFundStatusActive() external;

    function setFundStatusCompleted() external;

    function setFundStatusClosed() external;

    function getEndTime() external view returns (uint256);

    function getCurrentBalanceInWei() external view returns (uint256);

    function getCurrentBalanceInEFund() external view returns (uint256);

    function getCurrentBalanceTotal() external returns (uint256);
}
