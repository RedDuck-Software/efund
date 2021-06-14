// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./Interfaces/IHedgeFund.sol";
import "./FundFactory.sol";
import "./Interfaces/IFundTrade.sol";
import "./Interfaces/IFixedOracle.sol";

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
    using OZSignedSafeMath for int256;

    function calculateNumberFromNumberProcentage(int256 a, int256 b)
        internal
        pure
        returns (int256)
    {
        return a.mul(10**18).div(b);
    }

    function calculateNumberFromProcentage(int256 p, int256 all)
        internal
        pure
        returns (int256)
    {
        return int256(all.mul(p).div(10**18));
    }
}

contract HedgeFund is IHedgeFund, IFundTrade {
    event NewDeposit(
        address payable indexed _depositOwner,
        uint256 indexed _id,
        uint256 _depositAmount
    );

    event FundStatusChanged(uint256 _newStatus);

    event DepositWithdrawedBeforeActiveState(
        address payable indexed _depositOwner,
        uint256 indexed _id
    );
    
    event TokensSwap(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountFrom,
        uint256 _amountTo
    );

    event AllDepositsWithdrawed();

    using AddressArrayExstensions for address payable[];

    UniswapV2Router02 private router;

    DepositInfo[] public deposits;

    FundStatus public fundStatus;

    IUFundOracle public oracle;

    IERC20 public eFund;

    uint256 public softCap;

    uint256 public hardCap;

    address public uniswapv2RouterAddress;

    uint256 public constant depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    address payable public fundManager;

    uint256 public fundDurationMonths;

    uint256 public fundStartTimestamp;

    uint256 public baseBalance;

    uint256 public endBalance;

    address payable[] public boughtTokenAddresses;

    address payable[] public allowedTokenAddresses;

    bool public isDepositsWithdrawed;

    modifier onlyForFundManager() {
        require(
            msg.sender == fundManager || msg.sender == address(this),
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

    modifier onlyInComplitedState() {
        require(
            fundStatus == FundStatus.COMPLETED,
            "Fund should be in an Complited status"
        );
        _;
    }

    modifier onlyInOpenedState() {
        require(
            fundStatus == FundStatus.OPENED,
            "Fund should be in an Opened status"
        );
        _;
    }

    constructor(
        address payable _swapRouterContract,
        address payable _eFundContract,
        address _oracleContract,
        uint256 _softCap,
        uint256 _hardCap,
        address payable _managerAddress,
        uint256 _durationMonths,
        address payable[] memory _allowedTokenAddresses
    ) public {
        require(_validateDuration(_durationMonths), "Invalid duration");
        uniswapv2RouterAddress = _swapRouterContract;
        router = UniswapV2Router02(_swapRouterContract);
        eFund = IERC20(_eFundContract);
        oracle = IUFundOracle(_oracleContract);
        fundManager = _managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = _durationMonths;
        softCap = _softCap;
        hardCap = _hardCap;
        allowedTokenAddresses = _allowedTokenAddresses;
        isDepositsWithdrawed = false;
    }

    function getCurrentBalanceInWei() external view override returns (uint256) {
        return address(this).balance;
    }



    function getEndTime() external view override returns (uint256) {
        return fundStartTimestamp + (fundDurationMonths * 30 days);
    }

    /// @notice test function, using to determine is there connection with uni|cake swap or it`s not
    function getWETH() external view override returns (address) {
        return router.WETH();
    }

    function setFundStatusActive()
        external
        override
        onlyInOpenedState
        onlyForFundManager
    {
        fundStatus = FundStatus.ACTIVE;
        baseBalance = this.getCurrentBalanceInWei();
        fundStartTimestamp = block.timestamp;

        emit FundStatusChanged(uint256(fundStatus));
    }

    function setFundStatusClosed()
        external
        override
        onlyInComplitedState
        onlyForFundManager
    {
        fundStatus = FundStatus.CLOSED;
        emit FundStatusChanged(uint256(fundStatus));
    }

    function setFundStatusCompleted() external override onlyInActiveState {
        require(
            block.timestamp > this.getEndTime(),
            "Fund is didn`t finish yet"
        );

        this.swapAllTokensIntoETH();

        fundStatus = FundStatus.COMPLETED;

        // if(endBalance - baseBalance > 0) {
        //     endBalance = eFund.balanceOf(address(this)) - ;
        // }

        endBalance = this.getCurrentBalanceInWei();
        emit FundStatusChanged(uint256(fundStatus));
    }

    /// @notice make deposit into hedge fund. Default min is 0.1 ETH and max is 100 ETH in eFund equivalent
    function makeDeposit() external payable override onlyInOpenedState {
        require(
            msg.value >= softCap,
            "Transaction value is less then minimum deposit amout"
        );

        require(
            this.getCurrentBalanceInWei() + msg.value <= hardCap,
            "Max cap in 100 ETH is overflowed. Try to send less WEI"
        );

        DepositInfo memory deposit = DepositInfo(msg.sender, msg.value);

        deposits.push(deposit);
    }

    /// @notice withdraw your deposits before trading period is started
    function withdrawBeforeFundStarted() external override onlyInOpenedState {
        bool haveDeposits = false;

        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].depositOwner == payable(msg.sender)) {
                haveDeposits = true;
                _withdraw(deposits[i]);
                emit DepositWithdrawedBeforeActiveState(msg.sender, i);
                delete deposits[i];
            }
        }
        require(haveDeposits, "You have not any deposits in hedge fund");
    }

    function withdraw() external override {
        require(
            fundStatus == FundStatus.COMPLETED ||
                fundStatus == FundStatus.CLOSED,
            "Fund is not complited yet"
        );

        require(!isDepositsWithdrawed, "All deposits are already withdrawed");

        for (uint256 i; i < deposits.length; i++) {
            _withdraw(deposits[i]);
            delete deposits[i];
        }
        isDepositsWithdrawed = true;

        emit AllDepositsWithdrawed();
    }

    function withdrawToManager() public onlyForFundManager {
        require(
            isDepositsWithdrawed,
            "Can withdraw only after all depositst were withdrawed"
        );

        fundManager.transfer(this.getCurrentBalanceInWei());
    }

    /* trading section */

    function swapERC20ToERC20(
        address payable tokenFrom,
        address payable tokenTo,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState onlyForFundManager returns (uint256) {
        require(
            boughtTokenAddresses.contains(tokenFrom),
            "You must to own {tokenFrom} first"
        );
        require(
            allowedTokenAddresses.length == 0
                ? true // if empty array specified, all tokens are valid for trade
                : allowedTokenAddresses.contains(tokenTo),
            "Trading with not allowed tokens"
        );

        address[] memory path = _createPath(tokenFrom, tokenTo);

        // how much {tokenTo} we can buy with {tokenFrom} token
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );

        IERC20(tokenFrom).approve(uniswapv2RouterAddress, amountIn);

        uint256[] memory amounts =
            router.swapExactTokensForTokens(
                amountIn,
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds // find out why deadline is there
            );

        if (!boughtTokenAddresses.contains(tokenTo))
            boughtTokenAddresses.push(tokenTo);

        emit TokensSwap(path[0], path[1], amountIn, amounts[1]);
        return amounts[1];
    }

    function swapERC20ToETH(
        address payable tokenFrom,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState onlyForFundManager returns (uint256) {
        address[] memory path = _createPath(tokenFrom, router.WETH());

        require(
            boughtTokenAddresses.contains(tokenFrom),
            "You need to own {tokenFrom} first"
        );

        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );

        IERC20(tokenFrom).approve(uniswapv2RouterAddress, amountIn);

        uint256[] memory amounts =
            router.swapExactTokensForETH(
                amountIn,
                amountOut,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

        emit TokensSwap(path[0], path[1], amountIn, amounts[1]);


        return amounts[1];
    }

    function swapETHToERC20(
        address payable tokenTo,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState onlyForFundManager returns (uint256) {
        require(
            allowedTokenAddresses.length == 0
                ? true // if empty array specified, all tokens are valid for trade
                : allowedTokenAddresses.contains(tokenTo),
            "Trading with not allowed tokens"
        );

        address[] memory path = _createPath(router.WETH(), tokenTo);

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

        if (!boughtTokenAddresses.contains(tokenTo))
            boughtTokenAddresses.push(tokenTo);

        emit TokensSwap(path[0], path[1], amountIn, amounts[1]);

        return amounts[1];
    }

    function swapAllTokensIntoETH() public onlyForFundManager {
        require(fundStatus != FundStatus.OPENED, "Fund should be started");

        for (uint256 i; i < boughtTokenAddresses.length; i++) {
            address[] memory path =
                _createPath(boughtTokenAddresses[i], router.WETH());

            uint256 amountIn =
                IERC20(boughtTokenAddresses[i]).balanceOf(address(this));

            IERC20(boughtTokenAddresses[i]).approve(
                uniswapv2RouterAddress,
                amountIn
            );

            uint256[] memory amounts = router.swapExactTokensForETH(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

            emit TokensSwap(path[0], path[1], amountIn, amounts[1]);

            delete boughtTokenAddresses[i];
        }
    }

    function _withdraw(DepositInfo storage info) private {
        if (baseBalance == 0) {
            info.depositOwner.transfer(info.depositAmount);
            return;
        }

        int256 percentage =
            MathPercentage.calculateNumberFromNumberProcentage(
                int256(info.depositAmount),
                int256(baseBalance)
            );

        eFund.transfer(
            info.depositOwner,
            uint256(
                int256(info.depositAmount) +
                    MathPercentage.calculateNumberFromProcentage(
                        percentage,
                        int256(endBalance) - int256(baseBalance)
                    )
            )
        );

        // if (this.getCurrentBalanceInWei() != 0) {
        //     info.depositOwner.transfer(
        //         uint256(
        //             MathPercentage.calculateNumberFromProcentage(
        //                 percentage,
        //                 int256(endBalance)
        //             )
        //         )
        //     );
        // }
    }

    /// @dev create path array for uni|cake swap
    function _createPath(address tokenFrom, address tokenTo)
        private
        pure
        returns (address[] memory)
    {
        address[] memory path = new address[](2);

        path[0] = tokenFrom;
        path[1] = tokenTo;

        return path;
    }

    // validate hedge fund active state duration. Only valid 1,2,3,6 months
    function _validateDuration(uint256 _d) private pure returns (bool) {
        return _d == 1 || _d == 2 || _d == 3 || _d == 6;
    }

    // Functions to receive Ether
    receive() external payable {}

    fallback() external payable {}

    enum FundStatus {OPENED, ACTIVE, COMPLETED, CLOSED}

    struct DepositInfo {
        address payable depositOwner;
        uint256 depositAmount; // deposit amount in eFund
    }
}
