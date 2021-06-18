// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./SharedImports.sol";
import "./FundFactory.sol";

contract EFundPlatform is Ownable {
    FundFactory public immutable fundFactory;

    IERC20 public immutable eFund;

    mapping(address => bool) public isFund;

    mapping(address => uint256) public managersFundActivityStartedAt;

    address[] public funds;

    uint256 public constant silverPeriodStart = 3 * 30 days; // 3 months

    uint256 public constant goldPeriodStart = 6 * 30 days; // 6 months

    uint256 public constant percentageBase = 100;


    int256 private constant bronzePeriodRewardPercentage = 10; // 10%

    int256 private constant silverPeriodRewardPercentage = 20; // 20%

    int256 private constant goldPeriodRewardPercentage = 30; // 30%

   
    modifier onlyForFundContract() {
        require(isFund[msg.sender], "Caller address is not a fund");
        _;
    }

    constructor(address _fundFactory, address _efundToken) public {
        require(_fundFactory != address(0), "Invalid token address provided");

        fundFactory = FundFactory(_fundFactory);
        eFund = IERC20(_efundToken);
    }

    function createFund(
        address payable _swapRouterContract,
        uint256 _fundDurationInMonths,
        address payable[] memory _allowedTokens
    ) public payable returns (address) {
        address newFundAddress = fundFactory.createFund{value: msg.value}(
            _swapRouterContract,
            payable(address(eFund)),
            msg.sender,
            address(this),
            _fundDurationInMonths,
            _allowedTokens
        );
        
        funds.push(newFundAddress);
    }

    function getAllFunds() public view returns (address[] memory) {
        return funds;
    }

    function calculateRewardPercentage(address _address)
        public
        view
        returns (int256)
    {
        require(
            managersFundActivityStartedAt[_address] != 0,
            "Address is not a eFund manager"
        );

        return
            _calculateRewardPercentage(managersFundActivityStartedAt[_address]);
    }

    function _calculateRewardPercentage(uint256 _duration)
        private
        pure
        returns (int256)
    {
        if (_duration < silverPeriodStart) return bronzePeriodRewardPercentage;
        if (_duration < goldPeriodStart) return silverPeriodRewardPercentage;
        return goldPeriodRewardPercentage;
    }
}
