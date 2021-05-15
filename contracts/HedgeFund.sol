// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol"

interface HedgeFundContractInterface {
 
    function getWETH() external view returns (address);

    function makeDepositInETH() external payable;

    function makeDepositInERC20(address contractAddress, uint256 amount) external;

    function makeDepositInDefaultToken(uint256 amount) external;

    function withdraw() external;
}

contract HedgeFund is TestContractInterface {
    UniswapV2Router02 private router;

    DepositInfo[] public deposits;

    address payable private uniswapv2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public immutable depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    //uint256 public immutable minimumDepositTime = 7 * 24 * 60 * 60; //  30 days (time after withraw can be available)


    //address public defalutDepositTokenAddress;


    uint256 immutable public hardCap = 100000000000000000000;

    FundStatus public fundStatus;

    address public fundManager;

    constructor(address managerAddress)
        public
    {
        router = UniswapV2Router02(uniswapv2RouterAddress);
        fundManager = managerAddress;
        fundStatus = FundStatus.OPENED;
    }

    function getWETH() external view override returns (address) {
        return router.WETH();
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
        for(uint i; i < deposits.length; i++) {
            if(deposits[i].withdrawTime > block.timestamp || deposits[i].isWithdrawed) continue;
            _withdraw(deposits[i]);
        }   
    }



    function _withdraw(DepositInfo storage info) private { 
        
    }
    

    enum FundStatus { OPENED, ACTIVE, COMPLETED, CLOSED}

    struct DepositInfo {
        address depositOwner;
        uint256 depositAmount; // deposit amount in WETH
        address depositContractAddress; // address of the erc20 token, from which deposit was made. 0 - if deposit in ETH
        uint256 withdrawTime; // time when withdraw will be available
        bool isWithdrawed;
    }
}
