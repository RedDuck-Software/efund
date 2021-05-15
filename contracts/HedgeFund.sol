// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol"
import "./Interfaces/"




contract HedgeFund is IHedgeFund {
    UniswapV2Router02 private router;

    DepositInfo[] public deposits;

    address payable private uniswapv2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public immutable depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    uint256 immutable public hardCap = 100000000000000000000;

    FundStatus public fundStatus;

    address public fundManager;

    int public fundDurationMonths;

    uint256 public fundStartTimestamp;

    uint256 public baseBalance;

    uint256 public endBalance;


    modifier onlyForFundManager() {
        require(msg.sender == fundManager, "You have not permissions to this action");

        _;
    }

    constructor(address managerAddress, int durationMonths)
        public
    {
        require(_validateDuration(durationMonths), "Invalid duration");
        router = UniswapV2Router02(uniswapv2RouterAddress);
        fundManager = managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = duration;
        fundStartTimestamp = block.timestamp;
    }

    function getWETH() external view override returns (address) {
        return router.WETH();
    }

    function setFundStatusActive() public onlyForFundManager { 
        fundStatus = FundStatus.ACTIVE;
        baseBalance = address(this).balance;
    }

    function makeDepositInDefaultToken(uint256 amount) external override {
        OZIERC20 token = OZERC20(defalutDepositTokenAddress);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        token.transferFrom(msg.sender, address(this), amount);
    }

    function makeDepositInERC20(address contractAddress, uint256 amount)
        external
        override
    {
        address[] memory path = new address[](2);

        path[0] = contractAddress;
        path[1] = defalutDepositTokenAddress;

        // how much [defaultDepositToken] we can buy with [contractAddress] token
        uint256 amountOut = router.getAmountsOut(amount, path)[1];

        uint256[] memory amounts =
            router.swapExactTokensForTokens(
                amount,
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        DepositInfo memory deposit =
            DepositInfo(msg.sender, amounts[1], address(0), false);

        deposits.push(deposit);
    }

    function makeDepositInETH() external payable override {
        require(
            msg.value > minimalDepositAmountInWEI,
            "Transaction value is less then minimum deposit amout"
        );

        address[] memory path = new address[](2);

        path[0] = this.getWETH();
        path[0] = defalutDepositTokenAddress;

        uint256 amountOut = router.getAmountsOut(msg.value, path)[1];

        uint256[] memory amounts =
            router.swapExactETHForTokens(
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        DepositInfo memory deposit =
            DepositInfo(msg.sender, amounts[1], address(0), withdraw, block.timestamp + minimumDepositTime , false);

        deposits.push(deposit);
    }

    function withdraw() external override  {
        require(fundStartTimestamp +  _monthToSeconds(fundDurationMonths) < block.timestamp, "Fund is not complited yet");
        for(uint i; i < deposits.length; i++) {
            _withdraw(deposits[i]);
        }   
    }


    function _monthToSeconds(int _m) view {
        return _m * 30 * 24 * 60 * 60;
    }

    function _withdraw(DepositInfo storage info) private {
        info.depositOwner.transfer(info.depositAmount);
    }

    function _validateDuration(int _d) private returns (bool){ 
        return _d == 1 || _d == 2 || _d == 3 || _d == 6;
    }
    
    enum FundStatus { OPENED, ACTIVE, COMPLETED, CLOSED}

    struct DepositInfo {
        address depositOwner;
        uint256 depositAmount; // deposit amount in ETH
        //address depositContractAddress; // address of the erc20 token, from which deposit was made. 0 - if deposit in ETH
        //uint256 withdrawTime; // time when withdraw will be available
        //bool isWithdrawed;
    }
}
