// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6; // because of uniswap

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IFundFactory.sol";

contract FundFactory is IFundFactory {
    uint256 public immutable softCap = 1000000000000000; // -00
    uint256 public immutable hardCap = 100000000000000000000; // -0

    address[] public funds;

    function createFund(
        address payable swapRouterContract,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external payable override returns (address fundAddress) {
        require(
            msg.value >= softCap && msg.value <= hardCap,
            "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH"
        );

        HedgeFund newFund =
            new HedgeFund(
                swapRouterContract,
                softCap,
                hardCap,
                msg.sender,
                _fundDurationInMonths,
                allowedTokens
            );

        _sendEth(payable(address(newFund)), msg.value);

        funds.push(address(newFund));

        return address(newFund);
    }

    // todo: ask guys in chats
    function _sendEth(address payable _to, uint256 _value)
        private
        returns (bool)
    {
        (bool sent, ) = _to.call{value: _value}("");
        require(sent, "could not send ether to the fund");
    }
}
