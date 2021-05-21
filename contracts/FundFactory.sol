// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6; // because of uni|cake swap

import "./SharedImports.sol";
import "./HedgeFund.sol";
import "./Interfaces/IFundFactory.sol";
import "./UFundOracle.sol";
import "./Tokens/ERC20/eFund.sol";

contract FundFactory is IFundFactory {
    uint256 public immutable softCap = 100000000000000000;
    uint256 public immutable hardCap = 1000000000000000000000;

    address[] public funds;

    IUFundOracle public oracle;
    IERC20 public eFundToken;

    constructor(address _oracleAddress, address payable _eFundAddress) public {
        oracle = IUFundOracle(_oracleAddress);
        eFundToken = IERC20(_eFundAddress);
    }

    function createFund(
        address payable _swapRouterContract,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external payable override returns (address fundAddress) {
        require(
            msg.value >= softCap && msg.value <= hardCap,
            "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH"
        );

        HedgeFund newFund =
            new HedgeFund(
                _swapRouterContract,
                payable(address(eFundToken)),
                payable(address(oracle)),
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

    function createFundWithEFund(
        uint256 _initialDepositTokens,
        address payable _swapRouterContract,
        uint256 _fundDurationInMonths,
        address payable[] calldata allowedTokens
    ) external override returns (address fundAddress) {
        require(
            oracle.getPriceInETH(_initialDepositTokens) >= softCap &&
                oracle.getPriceInETH(_initialDepositTokens) <= hardCap,
            "To create fund you need to send minimum 0.1 ETH and maximum 100 ETH in eFund equivalent"
        );

        eFundToken.transferFrom(
            msg.sender,
            address(this),
            oracle.getPriceInEFund(softCap)
        );

        HedgeFund newFund =
            new HedgeFund(
                _swapRouterContract,
                payable(address(eFundToken)),
                payable(address(oracle)),
                softCap,
                hardCap,
                msg.sender,
                _fundDurationInMonths,
                allowedTokens
            );

        eFundToken.transfer(address(newFund), oracle.getPriceInEFund(softCap));

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
