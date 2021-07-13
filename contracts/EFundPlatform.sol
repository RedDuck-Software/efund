// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./FundFactory.sol";
import "./HedgeFund.sol";

contract EFundPlatform {
    using OZSafeMath for uint256;

    event ClaimHolderRewardSuccessfully(
        address recipient,
        uint256 ethReceived,
        uint256 nextAvailableClaimDate
    );

    FundFactory public immutable fundFactory;

    IERC20 public immutable eFund;

    mapping(address => bool) public isFund;

    mapping(address => FundManagerActivityInfo) public managerFundActivity;

    mapping(address => uint256) public nextAvailableRewardClaimDate;

    mapping(address => bool) public isExcludedFromReward;


    HedgeFund[] public funds;

    uint256 public constant rewardCycleBlock = 7 days;

    uint256 public constant silverPeriodStart = 3 * 30 days; // 3 months

    uint256 public constant goldPeriodStart = 6 * 30 days; // 6 months

    uint256 public constant percentageBase = 100;

    int256 public constant bronzePeriodRewardPercentage = 10; // 10%

    int256 public constant silverPeriodRewardPercentage = 20; // 20%

    int256 public constant goldPeriodRewardPercentage = 30; // 30%
    
    uint256 public immutable softCap;

    uint256 public immutable hardCap;

    modifier onlyForFundContract() {
        require(isFund[msg.sender], "Caller address is not a fund");
        _;
    }

    constructor(address _fundFactory, address _efundToken, uint256 _softCap, uint256 _hardCap ) public {
        require(_fundFactory != address(0), "Invalid fundFactory address provided");
        require(_efundToken != address(0), "Invalid eFund token address provided");
        require( _hardCap > _softCap, "Hard cap must be bigger than soft cap");

        hardCap = _hardCap;
        softCap = _softCap;

        fundFactory = FundFactory(_fundFactory);
        eFund = IERC20(_efundToken);
    }

    function createFund(
        address payable _swapRouter,
        uint256 _fundDurationInMonths,
        uint256 _softCap, 
        uint256 _hardCap, 
        address payable[] memory _allowedTokens
    ) public payable returns (address) {
        require( _hardCap > _softCap, "Hard cap must be bigger than soft cap");

        require(
            _hardCap <= hardCap && _softCap >= softCap,
            "Soft cap must be > 0.1 ETH and hard cap < 100 ETH"
        );

        require(
            msg.value >= _softCap && msg.value <= _hardCap,
            "value is outside of caps"
        );


        address newFundAddress =
            fundFactory.createFund{value: msg.value}(
                _swapRouter,
                payable(address(eFund)),
                msg.sender,
                address(this),
                _fundDurationInMonths,
                _softCap,
                _hardCap,
                _allowedTokens
            );

        funds.push(HedgeFund(payable(newFundAddress)));
        isFund[newFundAddress] = true;
        managerFundActivity[msg.sender] = FundManagerActivityInfo(0, true);
    }

    function getAllFunds() public view returns (HedgeFund[] memory) {
        return funds;
    }

    function getCurrentEthBalance() public view returns (uint256){
        return address(this).balance;
    }

    function closeFund() public onlyForFundContract {
        HedgeFund fund = HedgeFund(msg.sender); // sender is a contract 
        require(fund.getEndTime() <= block.timestamp, "Fund is not completed");

        uint256 _curActivity = managerFundActivity[fund.fundManager()].fundActivityDuration;
        managerFundActivity[fund.fundManager()].fundActivityDuration = _curActivity.add(fund.fundDuration());
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
        nextAvailableRewardClaimDate[msg.sender] =
            block.timestamp.add(rewardCycleBlock);

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
        uint256 _totalSupply = 
            eFund.totalSupply()
            .sub(eFund.balanceOf(address(this)))
            .sub(eFund.balanceOf(address(0)));


        return _calculateHolderReward(
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
        require(managerFundActivity[_address].isValue, "Address is not a fund manager");

        return
            _calculateManagerRewardPercentage(managerFundActivity[_address].fundActivityDuration);
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
        uint256 fundActivityDuration;
        bool isValue;
    }
}
