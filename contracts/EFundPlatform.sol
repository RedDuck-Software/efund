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

    HedgeFund[] public funds;

    uint256 public constant rewardCycleBlock = 7 days;

    uint256 public constant silverPeriodStart = 3 * 30 days; // 3 months

    uint256 public constant goldPeriodStart = 6 * 30 days; // 6 months

    uint256 public constant percentageBase = 100;

    int256 public constant bronzePeriodRewardPercentage = 10; // 10%

    int256 public constant silverPeriodRewardPercentage = 20; // 20%

    int256 public constant goldPeriodRewardPercentage = 30; // 30%

    modifier onlyForFundContract() {
        require(isFund[msg.sender], "Caller address is not a fund");
        _;
    }

    modifier onlyForFundManager() {
        require(managerFundActivity[msg.sender].isValue, "Caller address is not a fund manager");
        _;
    }

    constructor(address _fundFactory, address _efundToken) public {
        require(_fundFactory != address(0), "Invalid fundFactory address provided");
        require(_efundToken != address(0), "Invalid eFund token address provided");

        fundFactory = FundFactory(_fundFactory);
        eFund = IERC20(_efundToken);
    }

    function createFund(
        address payable _swapRouter,
        uint256 _fundDurationInMonths,
        address payable[] memory _allowedTokens
    ) public payable returns (address) {
        address newFundAddress =
            fundFactory.createFund{value: msg.value}(
                _swapRouter,
                payable(address(eFund)),
                msg.sender,
                address(this),
                _fundDurationInMonths,
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

        managerFundActivity[fund.fundManager()].fundActivityDurationMonths += fund.fundDurationMonths();
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
            block.timestamp +
            rewardCycleBlock;

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
        onlyForFundManager
        returns (int256)
    {
        return
            _calculateManagerRewardPercentage(managerFundActivity[_address].fundActivityDurationMonths);
    }


    function _calculateHolderReward(
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 totalSupply
    ) private pure returns (uint256) {
        uint256 reward = currentBNBPool.mul(currentBalance).div(totalSupply);
        return reward;
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
        uint256 fundActivityDurationMonths;
        bool isValue;
    }
}
