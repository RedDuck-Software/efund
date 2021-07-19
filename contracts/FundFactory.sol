// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6; // because of uni|cake swap

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IFundFactory.sol";
import "./Tokens/ERC20/eFund.sol";

contract FundFactory is IFundFactory {
    function createFund(HedgeFundInfo calldata _hedgeFundInfo) external payable override returns (address) {
        require(_hedgeFundInfo._hardCap > _hedgeFundInfo._softCap, "Hard cap must be bigger than soft cap");

        require(
            msg.value >= _hedgeFundInfo._softCap && msg.value <= _hedgeFundInfo._hardCap,
            "Invalid argument:Value sended must be >= softCap and <= hardCap"
        );

        HedgeFund newFund = new HedgeFund(_hedgeFundInfo);

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
