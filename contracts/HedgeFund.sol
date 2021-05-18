// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./Interfaces/IHedgeFund.sol";
import "./FundFactory.sol";
import "./Interfaces/IFundTrade.sol";

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

library MathPercentage {
    using OZSafeMath for uint256;

    function calculateNumberFromNumberProcentage(uint256 a, uint256 b)
        internal
        pure
        returns (uint256)
    {
        return b.div(a).mul(100);
    }

    function calculateNumberFromProcentage(uint256 p, uint256 all)
        internal
        pure
        returns (uint256)
    {
        return uint256(all.div(100).mul(p));
    }
}

contract HedgeFund is IHedgeFund, IFundTrade {
    using AddressArrayExstensions for address payable[];

    UniswapV2Router02 private router;

    DepositInfo[] public deposits;

    uint256 public softCap;

    uint256 public hardCap;

    address payable private uniswapv2RouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public immutable depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    FundStatus public fundStatus;

    address public fundManager;

    uint256 public fundDurationMonths;

    uint256 public fundStartTimestamp;

    // todo: current balance

    uint256 public baseBalance;

    uint256 public endBalance;

    address payable[] boughtTokenAddresses;

    address payable[] allowedTokenAddresses;

    modifier onlyForFundManager() {
        require(
            msg.sender == fundManager,
            "You have not permissions to this action"
        );
        _;
    }

    modifier onlyInActiveState() {
        require(
            fundStatus == FundStatus.ACTIVE,
            "Fund should be in an Active status"
        );
        _;
    }

    constructor(
        uint256 _softCap,
        uint256 _hardCap,
        address _managerAddress,
        uint256 _durationMonths,
        address payable[] memory _allowedTokenAddresses
    ) public {
        require(_validateDuration(_durationMonths), "Invalid duration");
        router = UniswapV2Router02(uniswapv2RouterAddress);
        fundManager = _managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = _durationMonths;
        softCap = _softCap;
        hardCap = _hardCap;
        allowedTokenAddresses = _allowedTokenAddresses;
    }

    function getEndTime() external view override returns (uint256) {
        return fundStartTimestamp + (fundDurationMonths * 30 days);
    }

    /// @notice test function, using to determine is there connection with UniSwap or it`s not
    function getWETH() external view override returns (address) {
        return router.WETH();
    }

    function setFundStatusActive() external override onlyForFundManager {
        fundStatus = FundStatus.ACTIVE;
        baseBalance = address(this).balance;
        fundStartTimestamp = block.timestamp;
    }

    function setFundStatusCompleted() external override {
        require(
            block.timestamp > this.getEndTime(),
            "Fund is didn`t finish yet"
        );
        _swapAllTokensIntoETH();

        fundStatus = FundStatus.COMPLETED;

        endBalance = address(this).balance;
        this.withdraw();
        this.setFundStatusClosed();
    }

    function setFundStatusClosed() external override {
        require(
            fundStatus == FundStatus.COMPLETED,
            "Fund must be completed to become closed"
        );
        fundStatus = FundStatus.CLOSED;
    }

    /// @notice make deposit in hedge fund. Default min is 0.1 ETH end max is 100 ETH
    function makeDepositInETH() external payable override {
        require(
            msg.value >= softCap && msg.value <= hardCap,
            "Transaction value is less then minimum deposit amout"
        );

        DepositInfo memory deposit = DepositInfo(msg.sender, msg.value);

        deposits.push(deposit);
    }

    /// @notice widthrow your deposits before trading period is started
    function widthrawBeforeFundStarted() external override {
        // todo: does have any deposits. If not - revert
        require(fundStatus == FundStatus.OPENED, "Fund is already started");

        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].depositOwner == payable(msg.sender)) {
                _withdraw(deposits[i]);
                delete deposits[i];
            }
        }
    }

    function withdraw() external override {
        require(
            fundStatus == FundStatus.COMPLETED,
            "Fund is not complited yet"
        );

        for (uint256 i; i < deposits.length; i++) {
            _withdraw(deposits[i]);
        }
    }

    /* trading section */

    function swapERC20ToERC20(
        address payable tokenFrom,
        address payable tokenTo,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState returns (uint256) {
        address[] memory path = new address[](2);

        require(
            boughtTokenAddresses.contains(tokenFrom),
            "You must to own {tokenFrom} first"
        );
        require(
            allowedTokenAddresses.length == 0
                ? true // if empty array specified, all tokens are valid for trade
                : allowedTokenAddresses.contains(tokenFrom) &&
                    allowedTokenAddresses.contains(tokenTo),
            "Trading with not allowed tokens"
        );

        path[0] = tokenFrom;
        path[1] = tokenTo;

        // how much {tokenTo} we can buy with {tokenFrom} token
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );

        uint256[] memory amounts =
            router.swapExactTokensForTokens(
                amountIn,
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        if (boughtTokenAddresses.contains(tokenTo))
            boughtTokenAddresses.push(tokenTo);

        return amounts[1];
    }

    function swapERC20ToETH(
        address payable tokenFrom,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState returns (uint256) {
        address[] memory path = new address[](2);

        require(
            boughtTokenAddresses.contains(tokenFrom),
            "You need to own {tokenFrom} first"
        );

        path[0] = tokenFrom;
        path[1] = router.WETH();

        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );

        uint256[] memory amounts =
            router.swapExactTokensForETH(
                amountIn,
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        return amounts[1];
    }

    function swapETHToERC20(
        address payable tokenTo,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState returns (uint256) {
        require(
            allowedTokenAddresses.contains(tokenTo),
            "Trading with not allowed tokens"
        );

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenTo;
        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );
        uint256[] memory amounts =
            router.swapETHForExactTokens{value: amountIn}(
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );
        if (boughtTokenAddresses.contains(tokenTo))
            boughtTokenAddresses.push(tokenTo);
        return amounts[1];
    }

    function swapERC20ToERC20(
        address payable tokenFrom,
        address payable tokenTo,
        uint256 amountIn
    ) external override onlyInActiveState returns (uint256) {
        return this.swapERC20ToERC20(tokenFrom, tokenTo, amountIn, 0);
    }

    function swapERC20ToETH(address payable tokenFrom, uint256 amountIn)
        external
        override
        onlyInActiveState
        returns (uint256)
    {
        return this.swapERC20ToETH(tokenFrom, amountIn, 0);
    }

    function swapETHToERC20(address payable tokenTo, uint256 amountIn)
        external
        override
        onlyInActiveState
        returns (uint256)
    {
        this.swapETHToERC20(tokenTo, amountIn, 0);
    }

    function _swapAllTokensIntoETH() private {
        for (uint256 i; i < boughtTokenAddresses.length; i++) {
            address[] memory path = new address[](2);

            path[0] = boughtTokenAddresses[i];
            path[1] = router.WETH();

            router.swapExactTokensForETH(
                IERC20(boughtTokenAddresses[i]).balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

            boughtTokenAddresses.removeAt(i);
        }
    }
    
    function _withdraw(DepositInfo storage info) private {
        uint256 percentage =
            MathPercentage.calculateNumberFromNumberProcentage(
                info.depositAmount,
                baseBalance
            );

        info.depositOwner.transfer(
            info.depositAmount +
                MathPercentage.calculateNumberFromProcentage(
                    percentage,
                    endBalance - baseBalance
                )
        );
    }

    // validate hendge fund active state duration. Only valid 1,2,3,6 months
    function _validateDuration(uint256 _d) private pure returns (bool) {
        return _d == 1 || _d == 2 || _d == 3 || _d == 6;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    enum FundStatus {OPENED, ACTIVE, COMPLETED, CLOSED}

    struct DepositInfo {
        address payable depositOwner;
        uint256 depositAmount; // deposit amount in ETH
    }
}
