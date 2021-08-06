// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./FundFactory.sol";
import "./HedgeFund.sol";
import "./Types/HedgeFundInfo.sol";

contract EFundPlatform {
    using OZSafeMath for uint256;

    event ClaimHolderRewardSuccessfully(
        address indexed recipient,
        uint256 indexed ethReceived,
        uint256 indexed nextAvailableClaimDate
    );

    HedgeFund[] private funds;

    mapping(address => HedgeFund[]) private managerFunds;

    mapping(address => HedgeFund[]) private investorFunds;

    FundFactory public immutable fundFactory;

    IERC20 public immutable eFund;

    mapping(address => bool) public isFund;

    mapping(address => FundManagerActivityInfo) public managerFundActivity;

    mapping(address => mapping(address => bool)) public isInvestorOf;

    mapping(address => uint256) public nextAvailableRewardClaimDate;

    mapping(address => bool) public isExcludedFromReward;

    uint256 public constant rewardCycleBlock = 7 days;

    uint256 public constant silverPeriodStart = 3 * 30 days; // 3 months

    uint256 public constant goldPeriodStart = 6 * 30 days; // 6 months

    uint256 public constant percentageBase = 100;

    int256 public constant bronzePeriodRewardPercentage = 10; // 10%

    int256 public constant silverPeriodRewardPercentage = 20; // 20%

    int256 public constant goldPeriodRewardPercentage = 30; // 30%

    int256 public constant noProfitFundFee = 3; // 3% - takes only when fund manager didnt made any profit of the fund

    uint256 public constant maximumMinimalDepositAmountFromHardCapPercentage =
        10;

    uint256 public constant minimumProfitFee = 1; // 1%

    uint256 public constant maximumProfitFee = 10; // 10%

    uint256 public constant minimumTimeUntillFundStart = 0 days;

    uint256 public constant maximumTimeUntillFundStart = 10 days;

    uint256 public immutable minimalManagerCollateral;

    uint256 public immutable softCap;

    uint256 public immutable hardCap;

    modifier onlyForFundContract() {
        require(isFund[msg.sender], "Caller address is not a fund");
        _;
    }

    constructor(
        address _fundFactory,
        address _efundToken,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _managerMinimalCollateral
    ) public {
        require(
            _fundFactory != address(0),
            "Invalid fundFactory address provided"
        );
        require(
            _efundToken != address(0),
            "Invalid eFund token address provided"
        );
        require(_hardCap > _softCap, "Hard cap must be bigger than soft cap");
        require(
            _managerMinimalCollateral < _hardCap,
            "Minumal manager collateral cannot be >= hardCap"
        );

        hardCap = _hardCap;
        softCap = _softCap;

        minimalManagerCollateral = _managerMinimalCollateral;

        fundFactory = FundFactory(_fundFactory);
        eFund = IERC20(_efundToken);
    }

    function getPlatformData()
        public
        view
        returns (
            uint256 _softCap,
            uint256 _hardCap,
            uint256 _minimumTimeUntillFundStart,
            uint256 _maximumTimeUntillFundStart,
            uint256 _minimumProfitFee,
            uint256 _maximumProfitFee,
            uint256 _minimalManagerCollateral
        )
    {
        return (
            softCap,
            hardCap,
            minimumTimeUntillFundStart,
            maximumTimeUntillFundStart,
            minimumProfitFee,
            maximumProfitFee,
            minimalManagerCollateral
        );
    }

    function createFund(
        address payable _swapRouter,
        uint256 _fundDurationInMonths,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _profitFee,
        uint256 _minimalDepositAmount,
        uint256 _minTimeUntilFundStart,
        address payable[] memory _allowedTokens
    ) public payable returns (address) {
        require(_hardCap > _softCap, "Hard cap must be bigger than soft cap");

        require(
            _hardCap <= hardCap && _softCap >= softCap,
            "HardCap values is outside the platform default caps"
        );

        require(
            _minimalDepositAmount > 0 &&
                _minimalDepositAmount <=
                _hardCap.div(maximumMinimalDepositAmountFromHardCapPercentage),
            "Invalid minimalDepositAmount"
        );

        require(
            msg.value >= minimalManagerCollateral && msg.value < _hardCap,
            "value must be < hard cap and > than minimum manager collateral"
        );

        require(
            _profitFee >= minimumProfitFee && _profitFee <= maximumProfitFee,
            "Manager fee value is outside the manager fee gap"
        );

        require(
            _minTimeUntilFundStart >= minimumTimeUntillFundStart &&
                _minTimeUntilFundStart <= maximumTimeUntillFundStart,
            "MinTimeUntillFundStart value is outside the fundStart gap"
        );

        address newFundAddress = fundFactory.createFund{value: msg.value}(
            HedgeFundInfo(
                _swapRouter,
                payable(address(eFund)),
                address(this),
                _softCap,
                _hardCap,
                _profitFee,
                _minimalDepositAmount,
                _minTimeUntilFundStart,
                msg.sender,
                _fundDurationInMonths,
                msg.value,
                _allowedTokens
            )
        );

        funds.push(HedgeFund(payable(newFundAddress)));
        managerFunds[msg.sender].push(HedgeFund(payable(newFundAddress)));
        isFund[newFundAddress] = true;

        if (!managerFundActivity[msg.sender].isValue)
            managerFundActivity[msg.sender] = FundManagerActivityInfo(
                0,
                0,
                0,
                true
            );
    }

    function getTopRelevantFunds(uint256 _topAmount)
        public
        view
        returns (HedgeFund[] memory)
    {
        if (funds.length == 0) return funds;

        if (_topAmount >= funds.length) _topAmount = funds.length;

        HedgeFund[] memory fundsCopy = new HedgeFund[](funds.length);

        for (uint256 i = 0; i < funds.length; i++) fundsCopy[i] = funds[i];

        HedgeFund[] memory relevantFunds = new HedgeFund[](_topAmount);

        for (uint256 i = 0; i < fundsCopy.length; i++) {
            for (uint256 j = 0; j < fundsCopy.length - i - 1; j++) {
                if (
                    managerFundActivity[fundsCopy[j].fundManager()]
                        .successCompletedFunds >
                    managerFundActivity[fundsCopy[j + 1].fundManager()]
                        .successCompletedFunds &&
                    address(fundsCopy[j]).balance >
                    address(fundsCopy[j + 1]).balance
                ) {
                    HedgeFund temp = fundsCopy[j + 1];
                    fundsCopy[j + 1] = fundsCopy[j];
                    fundsCopy[j] = temp;
                }
            }
        }

        uint256 j = funds.length - 1;

        for (uint256 i = 0; i < _topAmount; i++) {
            relevantFunds[i] = fundsCopy[j];
            j--;
        }

        return relevantFunds;
    }

    function getManagerFunds(address _manager)
        public
        view
        returns (HedgeFund[] memory)
    {
        return managerFunds[_manager];
    }

    function getInvestorFunds(address _investor)
        public
        view
        returns (HedgeFund[] memory)
    {
        return investorFunds[_investor];
    }

    function getAllFunds() public view returns (HedgeFund[] memory) {
        return funds;
    }

    function getCurrentEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function onDepositMade(address _depositorAddress)
        public
        onlyForFundContract
    {
        if (isInvestorOf[_depositorAddress][msg.sender]) return; // fund is already added to list of invested funds

        isInvestorOf[_depositorAddress][msg.sender] = true;
        investorFunds[_depositorAddress].push(HedgeFund(msg.sender));
    }

    function closeFund() public onlyForFundContract {
        HedgeFund fund = HedgeFund(msg.sender); // sender is a contract
        require(fund.getEndTime() < block.timestamp, "Fund is not completed");

        address managerAddresss = fund.fundManager();

        uint256 _curActivity = managerFundActivity[managerAddresss]
            .fundActivityMonths;

        managerFundActivity[managerAddresss].fundActivityMonths = _curActivity
            .add(fund.fundDurationMonths());

        managerFundActivity[managerAddresss]
            .completedFunds = managerFundActivity[managerAddresss]
            .completedFunds
            .add(1);

        managerFundActivity[managerAddresss]
            .successCompletedFunds = managerFundActivity[managerAddresss]
            .successCompletedFunds
            .add(fund.originalEndBalance() > fund.baseBalance() ? 1 : 0);
    }

    function claimHolderReward() public {
        require(
            nextAvailableRewardClaimDate[msg.sender] <= block.timestamp,
            "Error: next available not reached"
        );
        require(
            eFund.balanceOf(msg.sender) > 0,
            "Error: must own eFundToken to claim reward"
        );

        uint256 reward = calculateHolderReward(msg.sender);

        // update rewardCycleBlock
        nextAvailableRewardClaimDate[msg.sender] = block.timestamp.add(
            rewardCycleBlock
        );

        (bool sent, ) = address(msg.sender).call{value: reward}("");

        require(sent, "Error: Cannot withdraw reward");

        emit ClaimHolderRewardSuccessfully(
            msg.sender,
            reward,
            nextAvailableRewardClaimDate[msg.sender]
        );
    }

    function calculateHolderReward(address ofAddress)
        public
        view
        returns (uint256 reward)
    {
        uint256 _totalSupply = eFund
            .totalSupply()
            .sub(eFund.balanceOf(address(this)))
            .sub(eFund.balanceOf(address(0)));

        return
            _calculateHolderReward(
                eFund.balanceOf(address(ofAddress)),
                address(this).balance,
                _totalSupply
            );
    }

    function calculateManagerRewardPercentage(address _address)
        public
        view
        returns (int256)
    {
        require(
            managerFundActivity[_address].isValue,
            "Address is not a fund manager"
        );

        return
            _calculateManagerRewardPercentage(
                managerFundActivity[_address].fundActivityMonths
            );
    }

    function _calculateHolderReward(
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 totalSupply
    ) private pure returns (uint256) {
        uint256 reward = currentBNBPool.mul(currentBalance).div(totalSupply);
        return reward;
    }

    function _excludeFromReward(address _address) private {
        isExcludedFromReward[_address] = true;
    }

    function _calculateManagerRewardPercentage(uint256 _duration)
        private
        pure
        returns (int256)
    {
        if (_duration < silverPeriodStart) return bronzePeriodRewardPercentage;
        if (_duration < goldPeriodStart) return silverPeriodRewardPercentage;
        return goldPeriodRewardPercentage;
    }

    // Functions to receive Ether
    receive() external payable {}

    fallback() external payable {}

    struct FundManagerActivityInfo {
        uint256 fundActivityMonths;
        uint256 completedFunds;
        uint256 successCompletedFunds;
        bool isValue;
    }
}
