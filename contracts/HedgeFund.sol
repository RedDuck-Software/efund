// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./Interfaces/IHedgeFund.sol";
import "./FundFactory.sol";
import "./Interfaces/IFundTrade.sol";
import "./Libraries/MathPercentage.sol";
import "./EFundPlatform.sol";
import "./Types/HedgeFundInfo.sol";

struct SwapInfo { 
    address from;
    address to;
    uint256 amountFrom;
    uint256 amountTo;
    uint256 timestamp;
}

contract HedgeFund is IHedgeFund, IFundTrade {
    using OZSafeMath for uint256;

    event NewDeposit(
        address payable indexed _depositOwner,
        uint256 indexed _id,
        uint256 indexed _depositAmount
    );

    event FundStatusChanged(uint256 _newStatus);

    event DepositWithdrawedBeforeActiveState(
        address payable indexed _depositOwner,
        uint256 indexed _id
    );

    event TokensSwap(
        address indexed _tokenFrom,
        address indexed _tokenTo,
        uint256 _amountFrom,
        uint256 indexed _amountTo
    );

    event AllDepositsWithdrawed();

    DepositInfo[] private deposits;

    SwapInfo[] private swapsInfo;
    
    address payable[] private boughtTokenAddresses;

    address payable[] private allowedTokenAddresses;


    FundStatus public fundStatus;

    IERC20 public immutable eFundToken;

    EFundPlatform public immutable eFundPlatform;
    
    UniswapV2Router02 public immutable router;

    uint256 public immutable minimalDepositAmount;

    uint256 public immutable fundCreatedAt;

    uint256 public immutable fundCanBeStartedMinimumAt;

    uint256 public immutable softCap;

    uint256 public immutable hardCap;

    uint256 public immutable managerCollateral;

    address payable public immutable fundManager;

    uint256 public immutable fundDurationMonths;

    uint256 public fundStartTimestamp;

    uint256 public baseBalance;

    uint256 public endBalance;

    uint256 public lockedManagerProfit;
    
    mapping(address => bool) public isTokenBought; // this 2 mappings are needed to not iterate through arrays (that can be very big)

    mapping(address => bool) public isTokenAllowed;

    bool public isDepositsWithdrawed;

    int256 public constant managerProfitPercentage = 90; // 90%

    int256 public constant noProfitFundFee = 3; // 3% - takes only when fund manager didnt made any profit of the fund

    uint256 private constant depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    uint256 private constant monthDuration = 30 days;


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

    constructor(HedgeFundInfo memory _hedgeFundInfo) public {
        require(_validateDuration(_hedgeFundInfo._duration), "Invalid duration");
        
        router = UniswapV2Router02(_hedgeFundInfo._swapRouterContract);
        eFundToken = IERC20(_hedgeFundInfo._eFundTokenContract);
        eFundPlatform = EFundPlatform(_hedgeFundInfo._eFundPlatform);

        fundManager = _hedgeFundInfo._managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = _hedgeFundInfo._duration;
        softCap = _hedgeFundInfo._softCap;
        hardCap = _hedgeFundInfo._hardCap;
        allowedTokenAddresses = _hedgeFundInfo._allowedTokenAddresses;
        isDepositsWithdrawed = false;
        fundCreatedAt = block.timestamp;
        fundCanBeStartedMinimumAt = block.timestamp + _hedgeFundInfo.minTimeUntilFundStart;
        minimalDepositAmount = _hedgeFundInfo.minimalDepostitAmount; 
        managerCollateral = _getCurrentBalanceInWei();

        for (uint256 i; i < _hedgeFundInfo._allowedTokenAddresses.length; i++)
            isTokenAllowed[_hedgeFundInfo._allowedTokenAddresses[i]] = true;
    }

    function getAllDeposits() public view returns (DepositInfo[] memory){
        return deposits;
    }

    function getAllSwaps() public view returns (SwapInfo[] memory){
        return swapsInfo;
    }

    /// @notice get end time of the fund
    function getEndTime() external view override returns (uint256) {
        return _getEndTime();
    }

    function getBoughtTokensAddresses()
        public
        view
        returns (address payable[] memory)
    {
        return boughtTokenAddresses;
    }

    function getAllowedTokensAddresses()
        public
        view
        returns (address payable[] memory)
    {
        return allowedTokenAddresses;
    }

    function setFundStatusActive()
        external
        override
        onlyInOpenedState
        onlyForFundManager
    {
        require(fundCanBeStartedMinimumAt < block.timestamp, "Fund cannot be started at that moment");

        _updateFundStatus(FundStatus.ACTIVE);
        baseBalance = _getCurrentBalanceInWei();
        fundStartTimestamp = block.timestamp;

        emit FundStatusChanged(uint256(fundStatus));
    }

    function setFundStatusClosed()
        external
        override
        onlyInComplitedState
        onlyForFundManager
    {
        _updateFundStatus(FundStatus.CLOSED);
        eFundPlatform.closeFund();

        emit FundStatusChanged(uint256(fundStatus));
    }

    function setFundStatusCompleted() external override onlyInActiveState {
        // require(
        //     block.timestamp > _getEndTime(),
        //     "Fund is didn`t finish yet"
        // ); // commented for testing

        _updateFundStatus(FundStatus.COMPLETED);

        endBalance = _getCurrentBalanceInWei();

        uint256 fundFee = uint256(
            MathPercentage.calculateNumberFromPercentage(
                MathPercentage.translsatePercentageFromBase(
                    eFundPlatform.calculateManagerRewardPercentage(fundManager),
                    eFundPlatform.percentageBase()
                ),
                int256(endBalance)
            )
        );

        if (endBalance - fundFee > baseBalance) lockedManagerProfit = fundFee;

        emit FundStatusChanged(uint256(fundStatus));
    }

    /// @notice make deposit into hedge fund. Default min is 0.1 ETH and max is 100 ETH in eFund equivalent
    function makeDeposit() external payable override onlyInOpenedState {
        require(
            msg.value >= minimalDepositAmount,
            "Transaction value is less then minimum deposit amout"
        );

        require(
            _getCurrentBalanceInWei().add(msg.value) <= hardCap,
            "Max cap is overflowed. Try to send lower value"
        );

        DepositInfo memory deposit = DepositInfo(msg.sender, msg.value);

        deposits.push(deposit);
    }

    /// @notice withdraw your deposits before trading period is started
    function withdrawBeforeFundStarted() external override {
        require(fundCreatedAt.add(fundCanBeStartedMinimumAt) < block.timestamp, 
                "Cannot withdraw fund now"
        );

        bool haveDeposits = false;

        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].depositOwner == payable(msg.sender)) {
                DepositInfo memory depositsCopy = deposits[i];
                delete deposits[i];
                haveDeposits = true;
                _withdraw(depositsCopy);
                emit DepositWithdrawedBeforeActiveState(msg.sender, i);
            }
        }

        require(haveDeposits, "You have not any deposits in hedge fund");
    }

    function withdrawDeposits() external override {
        require(
            fundStatus == FundStatus.COMPLETED ||
                fundStatus == FundStatus.CLOSED,
            "Fund is not complited yet"
        );

        require(!isDepositsWithdrawed, "All deposits are already withdrawed");

        isDepositsWithdrawed = true;

        for (uint256 i; i < deposits.length; i++) {
            DepositInfo memory depositsCopy = deposits[i];
            delete deposits[i];
            _withdraw(depositsCopy);
        }

        emit AllDepositsWithdrawed();
    }

    function withdrawToManager() external override {
        require(
            isDepositsWithdrawed,
            "Can withdraw only after all depositst were withdrawed"
        );

        require(address(this).balance > 0, "Balance is 0, nothing to withdraw");

        uint256 platformFeeAmount;

        if (baseBalance >= endBalance) {
            // take 3% fee
            platformFeeAmount = uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.translsatePercentageFromBase(
                        noProfitFundFee,
                        100
                    ),
                    int256(address(this).balance)
                )
            );
        } else {
            // otherwise, 90% to fund manager, 10% - to eFund platform
            platformFeeAmount = uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.translsatePercentageFromBase(
                        managerProfitPercentage,
                        100
                    ),
                    int256(address(this).balance)
                )
            );
        }

        // send fee to eFundPlatform
        payable(address(eFundPlatform)).transfer(platformFeeAmount);

        // sending the rest to the fund manager
        fundManager.transfer(_getCurrentBalanceInWei());
    }

    /* trading section */
    function swapERC20ToERC20(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState onlyForFundManager returns (uint256) {
        require(path.length >= 2, "Path must be >= 2");

        address tokenFrom = path[0];
        address tokenTo = path[path.length - 1];

        for (uint256 i; i < path.length; i++) {
            require(
                allowedTokenAddresses.length == 0
                    ? true // if empty array specified, all tokens are valid for trade
                    : isTokenAllowed[path[i]],
                "Trading with not allowed tokens"
            );
            require(
                isTokenBought[tokenFrom],
                "You must to own {tokenFrom} first"
            );
        }

        // how much {tokenTo} we can buy with {tokenFrom} token
        uint256 amountOut = router.getAmountsOut(amountIn, path)[
            path.length - 1
        ];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );

        IERC20(tokenFrom).approve(address(router), amountIn);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOut,
            path,
            address(this),
            block.timestamp + depositTXDeadlineSeconds
        );

        if (!isTokenBought[tokenTo]) {
            boughtTokenAddresses.push(payable(tokenTo));
            isTokenBought[tokenTo] = true;
        }

        _onTokenSwapAction(tokenFrom, tokenTo, amountIn, amounts[path.length - 1]);
        return amounts[1];
    }

    function swapERC20ToETH(
        address payable tokenFrom,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyInActiveState onlyForFundManager returns (uint256) {
        require(isTokenBought[tokenFrom], "You need to own {tokenFrom} first");

        address[] memory path = _createPath(tokenFrom, router.WETH());

        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );

        IERC20(tokenFrom).approve(address(router), amountIn);

        uint256[] memory amounts = router.swapExactTokensForETH(
            amountIn,
            amountOut,
            path,
            address(this),
            block.timestamp + depositTXDeadlineSeconds
        );

        _onTokenSwapAction(path[0], path[1], amountIn, amounts[1]);
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
                : isTokenAllowed[tokenTo],
            "Trading with not allowed tokens"
        );

        address[] memory path = _createPath(router.WETH(), tokenTo);

        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(
            amountOut >= amountOutMin,
            "Output amount is lower then {amountOutMin}"
        );
        uint256[] memory amounts = router.swapETHForExactTokens{
            value: amountIn
        }(
            amountOut,
            path,
            address(this),
            block.timestamp + depositTXDeadlineSeconds
        );

        if (!isTokenBought[tokenTo]) {
            boughtTokenAddresses.push(tokenTo);
            isTokenBought[tokenTo] = true;
        }
        _onTokenSwapAction(path[0], path[1], amountIn, amounts[1]);

        return amounts[1];
    }

    function _withdraw(DepositInfo memory info) private {
        if (fundStatus == FundStatus.OPENED) {
            info.depositOwner.transfer(info.depositAmount); // if baseBalance 0 - it`s a withdrawBeforeFundStated call
            return;
        }

        int256 percentage = MathPercentage.calculateNumberFromNumberPercentage(
            int256(info.depositAmount),
            int256(baseBalance)
        );

        info.depositOwner.transfer(
            uint256(
                int256(info.depositAmount) +
                    MathPercentage.calculateNumberFromPercentage(
                        percentage,
                        int256(endBalance) -
                            int256(baseBalance) -
                            int256(lockedManagerProfit)
                    )
            )
        );
    }

    function _getCurrentBalanceInWei() private view returns (uint256) {
        return address(this).balance;
    }

    function _updateFundStatus(FundStatus newFundStatus) private { 
        fundStatus = newFundStatus;
    }

    function _getEndTime() private  view returns (uint256){ 
        return fundStartTimestamp + (fundDurationMonths.mul(monthDuration));
    }

    function _onTokenSwapAction(address _tokenFrom, address _tokenTo, uint256 _amountFrom, uint256 _amountTo) private { 
        emit TokensSwap(_tokenFrom, _tokenTo, _amountFrom, _amountTo);

        swapsInfo.push( 
            SwapInfo(
                _tokenFrom,
                _tokenTo,
                _amountFrom,
                _amountTo,
                block.timestamp
            )
        );
    }

    /// @dev create path array for uni|cake|etc.. swap
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
        return _d > 0;
        // return _d == 1 || _d == 2 || _d == 3 || _d == 6;
    }

    // Functions to receive Ether
    receive() external payable {}

    fallback() external payable {}

    enum FundStatus {
        OPENED,
        ACTIVE,
        COMPLETED,
        CLOSED
    }

    struct DepositInfo {
        address payable depositOwner;
        uint256 depositAmount;
    }
}
