// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6; // because of uni|cake swap

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IFundFactory.sol";
import "./Tokens/ERC20/eFund.sol";

/* 
    ERR MSG ABBREVIATION

CE0 : Hard cap must be bigger than soft cap
CE1 : Invalid argument:Value sended must be >= softCap and <= hardCap

*/
contract FundFactory is IFundFactory {
    function createFund(HedgeFundInfo calldata _hedgeFundInfo) external payable override returns (address) {
        require(_hedgeFundInfo._hardCap > _hedgeFundInfo._softCap, "CE0");

        require(
            msg.value >= _hedgeFundInfo._softCap && msg.value <= _hedgeFundInfo._hardCap,
            "CE1"
        );

        HedgeFund newFund = new HedgeFund(_hedgeFundInfo);

        payable(address(newFund)).transfer(msg.value);

        return address(newFund);
    }
}