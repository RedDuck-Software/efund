// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "../SharedImports.sol";

library MathPercentage {
    using OZSignedSafeMath for int256;

    function calculateNumberFromNumberPercentage(int256 a, int256 b)
        internal
        pure
        returns (int256)
    {
        return a.mul(10**18).div(b);
    }

    function calculateNumberFromPercentage(int256 p, int256 all)
        internal
        pure
        returns (int256)
    {
        return int256(all.mul(p).div(10**18));
    }
}