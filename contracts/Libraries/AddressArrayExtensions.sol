// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

library AddressArrayExstensions {
    function removeAt(address payable[] storage arr, uint256 i) internal {
        if (arr.length == 0) return;

        arr[i] = arr[arr.length - 1];
        arr.pop();
    }

    function contains(address payable[] storage arr, address val)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] == val) return true;
        }

        return false;
    }
}