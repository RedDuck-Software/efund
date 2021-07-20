// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6; // because of uni|cake swap
pragma experimental ABIEncoderV2;

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IFundFactory.sol";
import "./Tokens/ERC20/eFund.sol";

contract FundFactory is IFundFactory {
    

    function createFund(
        address payable _swapRouterContract,
        address payable _eFundToken,
        address payable _fundOwner,
        address payable _eFundPlatform,
        uint256 _fundDuration,
        uint256 _softCap,
        uint256 _hardCap,
        address payable[] calldata allowedTokens,
        HedgeFundInfo calldata _info
    ) external payable override returns (address) {
        require(
            _hardCap > _softCap,
            "Hard cap must be bigger than soft cap"
        );

        require(
            msg.value >= _softCap && msg.value <= _hardCap,
            "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH"
        );

        HedgeFund newFund =
            new HedgeFund(
                _swapRouterContract,
                _eFundToken,
                _eFundPlatform,
                _softCap,
                _hardCap,
                _fundOwner,
                _fundDuration,
                allowedTokens,
                _info
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
