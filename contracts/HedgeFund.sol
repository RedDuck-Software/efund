// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./Interfaces/IHedgeFund.sol";

contract HedgeFund is IHedgeFund {
    UniswapV2Router02 private router;

    DepositInfo[] public deposits;

    address payable private uniswapv2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public immutable depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    uint256 public immutable hardCap = 100000000000000000000;

    uint256 public immutable softCap = 100000000000000000;

    FundStatus public fundStatus;

    address public fundManager;

    uint256 public fundDurationMonths;

    uint256 public fundStartTimestamp;

    uint256 public baseBalance;

    uint256 public endBalance;

    modifier onlyForFundManager() {
        require(
            msg.sender == fundManager,
            "You have not permissions to this action"
        );
        _;
    }

    constructor(address managerAddress, uint256 durationMonths) public {
        require(_validateDuration(durationMonths), "Invalid duration");
        router = UniswapV2Router02(uniswapv2RouterAddress);
        fundManager = managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = durationMonths;
        fundStartTimestamp = block.timestamp;
    }

    function getWETH() external view override returns (address) {
        return router.WETH();
    }

    function setFundStatusActive() public onlyForFundManager {
        fundStatus = FundStatus.ACTIVE;
        baseBalance = address(this).balance;
    }

    function setFundStatusComplited() public onlyForFundManager {
        require(fundStartTimestamp + _monthToSeconds(fundDurationMonths) <
                block.timestamp,"");

        fundStatus = FundStatus.COMPLETED;
        endBalance = address(this).balance;
    }

    function makeDepositInETH() external payable override {
        require(
            msg.value >= softCap && msg.value <= hardCap,
            "Transaction value is less then minimum deposit amout"
        );

        DepositInfo memory deposit = DepositInfo(msg.sender, msg.value);

        deposits.push(deposit);
    }

    // call this method, if you want widthrow your deposits before trading period started
    function widthrawBeforeFundStarted() external override { 
        require(
            fundStatus == FundStatus.OPENED, 
            "Fund is already started"
        );
        
        for(uint i=0; i < deposits.length; i++)  { 
            if(deposits[i].depositOwner == payable(msg.sender)) 
                _withdraw(deposits[i]);
        }
    }

    function withdraw() external override  {
        require(
            fundStatus == FundStatus.COMPLETED,
            "Fund is not complited yet"
        );

        for (uint256 i; i < deposits.length; i++) {
            _withdraw(deposits[i]);
        }
    }

    function _monthToSeconds(uint256 _m) private pure returns (uint256) {
        return uint256(_m) * 30 * 24 * 60 * 60;
    }

    function _withdraw(DepositInfo storage info) private {
        info.depositOwner.transfer(info.depositAmount);
    }

    // validate hendge fund active state duration. Only valid 1,2,3,6 months
    function _validateDuration(uint256 _d) private pure returns (bool) {
        return _d == 1 || _d == 2 || _d == 3 || _d == 6;
    }

    enum FundStatus {OPENED, ACTIVE, COMPLETED, CLOSED}

    struct DepositInfo {
        address payable depositOwner;
        uint256 depositAmount; // deposit amount in ETH
    }
}
