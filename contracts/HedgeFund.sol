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
    uint256 timeStamp;
    uint block;
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
        uint256 indexed _amount
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

    mapping(address => uint256) private userDeposits;
    
    address payable[] private boughtTokenAddresses;

    address payable[] private allowedTokenAddresses;

    FundStatus public fundStatus;

    IERC20 public immutable eFundToken;

    EFundPlatform public immutable eFundPlatform;

    UniswapV2Router02 public immutable router;

    uint256 private immutable minimalDepositAmount;

    uint256 public immutable fundCreatedAt;

    uint256 private immutable fundCanBeStartedMinimumAt;

    uint256 private immutable softCap;

    uint256 private immutable hardCap;

    uint256 private immutable managerCollateral;

    address payable public immutable fundManager;

    uint256 public immutable fundDurationMonths;

    uint256 private immutable profitFee;

    uint256 private fundStartTimestamp;

    uint256 public baseBalance;

    uint256 public endBalance;

    uint256 public lockedPlatforFee; // in eth|bnb

    mapping(address => bool) private isTokenBought; // this 2 mappings are needed to not iterate through arrays (that can be very big)

    mapping(address => bool) private isTokenAllowed;

    bool public isDepositsWithdrawed;

    uint256 private constant depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    uint256 private constant monthDuration = 30 days;


    modifier onlyForFundManager() {
        require(
            msg.sender == fundManager || msg.sender == address(this),
            "You have not permissions to this action"
        );
        _;
    }

    function onlyInActiveState() private view { 
        require(
            fundStatus == FundStatus.ACTIVE,
            "Fund should be in an Active status"
        );
    }

    function onlyInOpenedState() private view { 
        require(
            fundStatus == FundStatus.OPENED,
            "Fund should be in an Opened status"
        );
    }

    constructor(HedgeFundInfo memory _hedgeFundInfo) public {
        require(
            _validateDuration(_hedgeFundInfo.duration),
            "Invalid duration"
        );

        router = UniswapV2Router02(_hedgeFundInfo.swapRouterContract);
        eFundToken = IERC20(_hedgeFundInfo.eFundTokenContract);
        eFundPlatform = EFundPlatform(_hedgeFundInfo.eFundPlatform);

        fundManager = _hedgeFundInfo.managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = _hedgeFundInfo.duration;
        softCap = _hedgeFundInfo.softCap;
        hardCap = _hedgeFundInfo.hardCap;
        allowedTokenAddresses = _hedgeFundInfo.allowedTokenAddresses;
        isDepositsWithdrawed = false;
        fundCreatedAt = block.timestamp;
        fundCanBeStartedMinimumAt =
            block.timestamp +
            _hedgeFundInfo.minTimeUntilFundStart;
        minimalDepositAmount = _hedgeFundInfo.minimalDepostitAmount;
        managerCollateral = _hedgeFundInfo.managerCollateral;
        profitFee = _hedgeFundInfo.profitFee;

        for (uint256 i; i < _hedgeFundInfo.allowedTokenAddresses.length; i++)
            isTokenAllowed[_hedgeFundInfo.allowedTokenAddresses[i]] = true;
    }

    function getFundInfo()
        public
        view
        returns (
            address _fundManager,
            uint256 _fundStartTimestamp,
            uint256 _minDepositAmount,
            uint256 _fundCanBeStartedAt,
            uint256 _fundDurationInMonths,
            uint256 _profitFee,
            FundStatus _fundStatus,
            uint256 _currentBalance,
            uint256 _managerCollateral,
            uint256 _hardCap,
            uint256 _softCap,
            DepositInfo[] memory _deposits
            // uint256 _investorsAmount
        )
    {
        return (
            fundManager,
            fundStartTimestamp,
            minimalDepositAmount,
            fundCanBeStartedMinimumAt,
            fundDurationMonths,
            profitFee,
            fundStatus,
            address(this).balance,
            managerCollateral,
            hardCap,
            softCap,
            deposits
        );
    }

    function getAllDeposits() public view returns (DepositInfo[] memory) {
        return deposits;
    }

    function getAllSwaps() public view returns (SwapInfo[] memory) {
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
        onlyForFundManager
    {
        onlyInOpenedState();
        require(
            fundCanBeStartedMinimumAt < block.timestamp,
            "Fund cannot be started at that moment"
        );

        _updateFundStatus(FundStatus.ACTIVE);
        baseBalance = _getCurrentBalanceInWei();
        fundStartTimestamp = block.timestamp;

        emit FundStatusChanged(uint256(fundStatus));
    }

    function setFundStatusCompleted() external override {
        onlyInActiveState();
        // require(
        //     block.timestamp > _getEndTime(),
        //     "Fund is didn`t finish yet"
        // ); // commented for testing

        _updateFundStatus(FundStatus.COMPLETED);

        endBalance = _getCurrentBalanceInWei();
        
        uint256 fundFee;

        fundFee = uint256(
            MathPercentage.calculateNumberFromPercentage(
                MathPercentage.translsatePercentageFromBase(
                    int256(profitFee),
                    100
                ),
                int256(endBalance)
            )
        );

        if(endBalance > fundFee && endBalance.sub(fundFee) > baseBalance) { 
            lockedPlatforFee = fundFee;
        }else{ 
            lockedPlatforFee = uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.translsatePercentageFromBase(
                        int256(eFundPlatform.noProfitFundFee()),
                        100
                    ),
                    int256(endBalance)
                )
            );
        }
        
        eFundPlatform.closeFund();

        emit FundStatusChanged(uint256(fundStatus));
    }

    /// @notice make deposit into hedge fund. Default min is 0.1 ETH and max is 100 ETH in eFund equivalent
    function makeDeposit() external payable override {
        onlyInOpenedState();
        require(
            msg.value >= minimalDepositAmount,
            "Transaction value is less then minimum deposit amout"
        );

        require(
            _getCurrentBalanceInWei().add(msg.value) <= hardCap,
            "Max cap is overflowed. Try to send lower value"
        );

        DepositInfo memory deposit = DepositInfo(msg.sender, msg.value);

        userDeposits[msg.sender] = userDeposits[msg.sender].add(msg.value);

        deposits.push(deposit);
        
        eFundPlatform.onDepositMade(msg.sender);
    }

    /// @notice withdraw your deposits before trading period is started
    function withdrawBeforeFundStarted() external override {
        require(
            block.timestamp > fundCanBeStartedMinimumAt,
            "Cannot withdraw fund now"
        );

        require(
            userDeposits[msg.sender] != 0, 
            "You have no deposits in this fund"
        );
        uint256 totalDepositsAmount = userDeposits[msg.sender];

        userDeposits[msg.sender] = 0;

        _withdraw(DepositInfo(msg.sender, totalDepositsAmount));

        emit DepositWithdrawedBeforeActiveState(msg.sender, totalDepositsAmount);
    }
    
    function withdrawDeposits() external override {
        require(
            fundStatus == FundStatus.COMPLETED,
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
    

    /*  ERR MSG ABBREVIATION

        C0 : Can withdraw only after all depositst were withdrawed
        B0 : Balance is 0, nothing to withdraw
    */
    function withdrawManagerProfit() external override {
        require(
            isDepositsWithdrawed,
            "C0"
        );

        require(address(this).balance > 0, "B0");

        uint256 platformFeeAmount;

        if (baseBalance >= endBalance) {
            // take 3% fee, because fund is not succeed
            platformFeeAmount = uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.translsatePercentageFromBase(
                        eFundPlatform.noProfitFundFee(),
                        100
                    ),
                    int256(address(this).balance)
                )
            );
        } else {
            // otherwise
            platformFeeAmount = uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.translsatePercentageFromBase(
                        100 - eFundPlatform.calculateManagerRewardPercentage(fundManager),
                        100
                    ),
                    int256(address(this).balance)
                )
            );
        }

        // send fee to eFundPlatform
        if (_getCurrentBalanceInWei() > 0)
            payable(address(eFundPlatform)).transfer(platformFeeAmount);

        // sending the rest to the fund manager
        if (_getCurrentBalanceInWei() > 0)
            fundManager.transfer(_getCurrentBalanceInWei());
    }

    /*  ERR MSG ABBREVIATION

        P0 : Path must be >= 2
        T0 : Trading with not allowed tokens
        T1 : You must to own {tokenFrom} first
        T2 : Output amount is lower then {amountOutMin}
    */
    function swapERC20ToERC20(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override  onlyForFundManager returns (uint256) {
        onlyInActiveState();
        require(path.length >= 2, "P0");

        address tokenFrom = path[0];
        address tokenTo = path[path.length - 1];

        for (uint256 i; i < path.length; i++) {
            require(
                allowedTokenAddresses.length == 0
                    ? true // if empty array specified, all tokens are valid for trade
                    : isTokenAllowed[path[i]],
                "T0"
            );
            require(
                isTokenBought[tokenFrom],
                "T1"
            );
        }

        // how much {tokenTo} we can buy with {tokenFrom} token
        uint256 amountOut = router.getAmountsOut(amountIn, path)[
            path.length - 1
        ];

        require(
            amountOut >= amountOutMin,
            "T2"
        );

        IERC20(tokenFrom).approve(address(router), amountIn);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOut,
            path,
            address(this),
            block.timestamp.add(depositTXDeadlineSeconds)
        );

        if (!isTokenBought[tokenTo]) {
            boughtTokenAddresses.push(payable(tokenTo));
            isTokenBought[tokenTo] = true;
        }

        _onTokenSwapAction(
            tokenFrom,
            tokenTo,
            amountIn,
            amounts[path.length - 1]
        );
        return amounts[1];
    }

    function swapERC20ToETH(
        address payable tokenFrom,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override onlyForFundManager returns (uint256) {
        onlyInActiveState();
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
    ) external override onlyForFundManager returns (uint256) {
        onlyInActiveState();
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
                        int256(endBalance.sub(baseBalance).sub(lockedPlatforFee))
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

    function _getEndTime() private view returns (uint256) {
        return fundStartTimestamp + (fundDurationMonths.mul(monthDuration));
    }

    function _onTokenSwapAction(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountFrom,
        uint256 _amountTo
    ) private {
        emit TokensSwap(_tokenFrom, _tokenTo, _amountFrom, _amountTo);

        swapsInfo.push(
            SwapInfo(
                _tokenFrom,
                _tokenTo,
                _amountFrom,
                _amountTo,
                block.timestamp,
                block.number
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

    // validate hedge fund active state duration. Only valid: 0(testing),1,2,3,6 months
    function _validateDuration(uint256 _d) private pure returns (bool) {
        return _d == 0 || _d == 1 || _d == 2 || _d == 3 || _d == 6;
    }

    // Functions to receive Ether
    receive() external payable {}

    fallback() external payable {}

    enum FundStatus {
        OPENED,
        ACTIVE,
        COMPLETED
    }

    struct DepositInfo {
        address payable depositOwner;
        uint256 depositAmount;
    }
}
