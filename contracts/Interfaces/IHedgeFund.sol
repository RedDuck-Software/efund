// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

struct HedgeFundInfo {
    string name;
    string description;
    string imageUrl;
}

interface IHedgeFund {
    function makeDeposit() external payable;

    function withdrawDepositsOf(address payable _of) external;

    function withdrawDepositsBeforeFundStarted() external;

    function setFundStatusActive() external;

    function setFundStatusCompleted() external;

    function getEndTime() external view returns (uint256);

    function withdrawFundProfit() external;
}
