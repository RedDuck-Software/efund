const HedgeFundContractERC20 = artifacts.require("HedgeFundContractERC20");

module.exports = function (deployer) {
  deployer.deploy(HedgeFundContractERC20, "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735");
};
