// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6; // because of uni|cake swap

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IFundFactory.sol";
import "./UFundOracle.sol";
import "./Tokens/ERC20/eFund.sol";

contract FundFactory is IFundFactory {
    uint256 public constant softCap = 100000000000000000;
    uint256 public constant hardCap = 1000000000000000000000;

    function createFund(
        address payable _swapRouterContract,
        address payable _eFundToken,
        address payable _fundOwner,
        address _eFundPlatform,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external payable override returns (address) {
        require(
            msg.value >= softCap && msg.value <= hardCap,
            "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH"
        );

        HedgeFund newFund =
            new HedgeFund(
                _swapRouterContract,
                _eFundToken,
                _eFundPlatform,
                softCap,
                hardCap,
                _fundOwner,
                _fundDurationInMonths,
                allowedTokens
            );

        _sendEth(payable(address(newFund)), msg.value);

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
