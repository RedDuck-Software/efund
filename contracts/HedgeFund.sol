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
    uint256 block;
}

// library TradeLibrary {
//     function swapAllTokensIntoETH(UniswapV2Router02 router, address[] memory tokens, address to) public {
//         for (uint256 i; i < tokens.length; i++) {
//             address[] memory path = _createPath(
//                 tokens[i],
//                 router.WETH()
//             );

//             uint256 amountIn = IERC20(tokens[i]).balanceOf(
//                 address(this)
//             );

//             if (amountIn == 0) continue;

//             boughtTokenAddresses[i].deletgatecall(abi.encodeWithSignature("approve(address,uint256)",address(router),amountIn );

//             router.swapExactTokensForETH(
//                 amountIn,
//                 0,
//                 path,
//                 address(this),
//                 block.timestamp + depositTXDeadlineSeconds
//             );

//             delete boughtTokenAddresses[i];
//         }
//     }
// }

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

    event DepositsWitdrawed(
        address indexed _depositor,
        uint256 indexed _amount
    );

    DepositInfo[] private deposits;

    SwapInfo[] private swapsInfo;

    mapping(address => uint256) public userDeposits;

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

    uint256 public originalEndBalance;

    uint256 public lockedFundProfit; // in eth|bnb

    bool public fundProfitWitdrawed;

    mapping(address => bool) private isTokenBought; // this 2 mappings are needed to not iterate through arrays (that can be very big)

    mapping(address => bool) private isTokenAllowed;

    uint256 private constant depositTXDeadlineSeconds = 30 * 60; // 30 minutes  (time after which deposit TX will revert)

    uint256 private constant monthDuration = 30 days;

    /* 
        NP - You have not permissions to this action
        SA - Fund should be in an Active state
        SO - Fund should be in an Opened state
        SC - Fund should be in a Completed state
    */
    function onlyForFundManager() private view {
        require(msg.sender == fundManager || msg.sender == address(this), "NP");
    }

    function onlyInActiveState() private view {
        require(fundStatus == FundStatus.ACTIVE, "SA");
    }

    function onlyInOpenedState() private view {
        require(fundStatus == FundStatus.OPENED, "SO");
    }

    function onlyInCompletedState() private view {
        require(fundStatus == FundStatus.COMPLETED, "SC");
    }

    /* 
        ID - Invalid duration
    */
    constructor(HedgeFundInfo memory _hedgeFundInfo) public {
        require(_validateDuration(_hedgeFundInfo.duration), "ID");

        router = UniswapV2Router02(_hedgeFundInfo.swapRouterContract);
        eFundToken = IERC20(_hedgeFundInfo.eFundTokenContract);
        eFundPlatform = EFundPlatform(_hedgeFundInfo.eFundPlatform);

        fundManager = _hedgeFundInfo.managerAddress;
        fundStatus = FundStatus.OPENED;
        fundDurationMonths = _hedgeFundInfo.duration;
        softCap = _hedgeFundInfo.softCap;
        hardCap = _hedgeFundInfo.hardCap;
        allowedTokenAddresses = _hedgeFundInfo.allowedTokenAddresses;
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
        )
    // uint256 _investorsAmount
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

    /* 
        CS - Fund cannot be started at that moment
    */
    function setFundStatusActive() external override {
        onlyForFundManager();
        onlyInOpenedState();
        require(fundCanBeStartedMinimumAt < block.timestamp, "CS");

        _updateFundStatus(FundStatus.ACTIVE);
        baseBalance = _currentBalanceWithoutManagerCollateral();
        fundStartTimestamp = block.timestamp;

        emit FundStatusChanged(uint256(fundStatus));
    }

    /*
        NF - Fund is didn`t finish yet
    */
    function setFundStatusCompleted() external override {
        onlyInActiveState();
        require(block.timestamp > _getEndTime(), "NF"); // commented for testing

        _swapAllTokensIntoETH();

        _updateFundStatus(FundStatus.COMPLETED);

        // dosent count manager collateral
        originalEndBalance = _currentBalanceWithoutManagerCollateral();

        int256 totalFundFeePercentage;

        if (originalEndBalance < baseBalance) {
            totalFundFeePercentage = eFundPlatform.noProfitFundFee();
        } else {
            totalFundFeePercentage = int256(profitFee);
        }

        lockedFundProfit = uint256(
            MathPercentage.calculateNumberFromPercentage(
                MathPercentage.translsatePercentageFromBase(
                    totalFundFeePercentage,
                    100
                ),
                int256(originalEndBalance)
            )
        );

        if (originalEndBalance.sub(lockedFundProfit) < baseBalance) {
            // cannot pay all investemnts - so manager collateral counts too
            endBalance = _currentBalance();
        } else {
            endBalance = _currentBalanceWithoutManagerCollateral();
        }

        eFundPlatform.closeFund();

        emit FundStatusChanged(uint256(fundStatus));
    }

    /*
        FS - Fund should be started
    */
    function _swapAllTokensIntoETH() private {
        for (uint256 i; i < boughtTokenAddresses.length; i++) {
            address[] memory path = _createPath(
                boughtTokenAddresses[i],
                router.WETH()
            );

            uint256 amountIn = IERC20(boughtTokenAddresses[i]).balanceOf(
                address(this)
            );

            if (amountIn == 0) continue;

            IERC20(boughtTokenAddresses[i]).approve(address(router), amountIn);

            router.swapExactTokensForETH(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + depositTXDeadlineSeconds
            );

            delete boughtTokenAddresses[i];
        }
    }

    /// @notice make deposit into hedge fund. Default min is 0.1 ETH and max is 100 ETH in eFund equivalent
    /*
        TL - Transaction value is less then minimum deposit amout
        MO - Max cap is overflowed. Try to send lower value

    */
    function makeDeposit() external payable override {
        onlyInOpenedState();
        require(msg.value >= minimalDepositAmount, "TL");

        require(
            _currentBalanceWithoutManagerCollateral().add(msg.value) <= hardCap,
            "MO"
        );

        DepositInfo memory deposit = DepositInfo(msg.sender, msg.value);

        userDeposits[msg.sender] = userDeposits[msg.sender].add(msg.value);

        deposits.push(deposit);

        eFundPlatform.onDepositMade(msg.sender);
    }

    /// @notice withdraw your deposits before trading period is started
    /*
        CW - Cannot withdraw fund now
        ND - You have no deposits in this fund
    */
    function withdrawDepositsBeforeFundStarted() external override {
        onlyInOpenedState();
        require(block.timestamp > fundCanBeStartedMinimumAt, "CW");

        require(userDeposits[msg.sender] != 0, "ND");
        uint256 totalDepositsAmount = userDeposits[msg.sender];

        userDeposits[msg.sender] = 0;

        _withdraw(DepositInfo(msg.sender, totalDepositsAmount));

        emit DepositWithdrawedBeforeActiveState(
            msg.sender,
            totalDepositsAmount
        );
    }

    /*
        ND - Address has no deposits in this fund
    */
    function withdrawDepositsOf(address payable _of) external override {
        onlyInCompletedState();

        require(userDeposits[_of] != 0, "ND");

        uint256 totalDepositsAmount = userDeposits[_of];

        userDeposits[_of] = 0;

        _withdraw(DepositInfo(_of, totalDepositsAmount));

        emit DepositsWitdrawed(_of, totalDepositsAmount);
    }

    /* 
        B0 - Balance is 0, nothing to withdraw
        C0 - Can withdraw only after all depositst were withdrawed
        PW - Fund profit is already withdrawed
    */
    /// @dev withdraw manager and platform profits
    function withdrawFundProfit() external override {
        onlyInCompletedState();
        require(!fundProfitWitdrawed, "PW");
        require(_currentBalance() > 0, "B0");

        fundProfitWitdrawed = true;

        uint256 platformFee;
        uint256 managerProfit;

        if (baseBalance >= originalEndBalance) {
            platformFee = lockedFundProfit;
        } else {
            // otherwise
            platformFee = uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.translsatePercentageFromBase(
                        100 -
                            eFundPlatform.calculateManagerRewardPercentage(
                                fundManager
                            ),
                        100
                    ),
                    int256(lockedFundProfit)
                )
            );
        }

        // if manager > 0 means that fund was succeed and manager take some profit from it
        managerProfit = lockedFundProfit.sub(platformFee);

        // send fee to eFundPlatform
        if (_currentBalance() >= platformFee)
            payable(address(eFundPlatform)).transfer(platformFee);

        // sending the rest to the fund manager
        if (managerProfit > 0 && _currentBalance() >= managerProfit) {
            fundManager.transfer(managerProfit);
        }

        // withdraw manager collaterall
        // if originalEndBalance == endBalance - manager collateral doesnt included into endBalance
        if (
            managerProfit > 0 &&
            originalEndBalance == endBalance &&
            _currentBalance() >= managerCollateral
        ) {
            fundManager.transfer(managerCollateral);
        }
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
    ) external override {
        onlyForFundManager();
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
            require(isTokenBought[tokenFrom], "T1");
        }

        // how much {tokenTo} we can buy with {tokenFrom} token
        uint256 amountOut = router.getAmountsOut(amountIn, path)[
            path.length - 1
        ];

        require(amountOut >= amountOutMin, "T2");

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
    }

    /*
        NO - You need to own {tokenFrom} first
        OL - Output amount is lower then {amountOutMin}
    */
    function swapERC20ToETH(
        address payable tokenFrom,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override {
        onlyForFundManager();
        onlyInActiveState();
        require(isTokenBought[tokenFrom], "NO");

        address[] memory path = _createPath(tokenFrom, router.WETH());

        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(amountOut >= amountOutMin, "OL");

        IERC20(tokenFrom).approve(address(router), amountIn);

        uint256[] memory amounts = router.swapExactTokensForETH(
            amountIn,
            amountOut,
            path,
            address(this),
            block.timestamp + depositTXDeadlineSeconds
        );

        _onTokenSwapAction(path[0], path[1], amountIn, amounts[1]);
    }

    /*
        IA - Insufficient amount of ETH
        NA - Trading with not allowed tokens
        OL - Output amount is lower then {amountOutMin}
    */
    function swapETHToERC20(
        address payable tokenTo,
        uint256 amountIn,
        uint256 amountOutMin
    ) external override {
        onlyForFundManager();
        onlyInActiveState();
        require(amountIn < _currentBalanceWithoutManagerCollateral(), "IA");

        require(
            allowedTokenAddresses.length == 0
                ? true // if empty array specified, all tokens are valid for trade
                : isTokenAllowed[tokenTo],
            "NA"
        );

        address[] memory path = _createPath(router.WETH(), tokenTo);

        // how much {tokenTo} we can buy with ether
        uint256 amountOut = router.getAmountsOut(amountIn, path)[1];

        require(amountOut >= amountOutMin, "OL");
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
    }

    function _withdraw(DepositInfo memory info) private {
        if (fundStatus == FundStatus.OPENED) {
            // if opened - it`s withdrawDepositsBeforeFundStarted call
            info.depositOwner.transfer(info.depositAmount);
            return;
        }

        info.depositOwner.transfer(
            uint256(
                MathPercentage.calculateNumberFromPercentage(
                    MathPercentage.calculateNumberFromNumberPercentage(
                        int256(info.depositAmount),
                        int256(baseBalance)
                    ),
                    int256(endBalance.sub(lockedFundProfit))
                )
            )
        );
    }

    /// @return balance of current fund without managerCollateral
    function _currentBalanceWithoutManagerCollateral()
        private
        view
        returns (uint256)
    {
        return _currentBalance().sub(managerCollateral);
    }

    function _currentBalance() private view returns (uint256) {
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
