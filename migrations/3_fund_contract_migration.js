const HedgeFund = artifacts.require("HedgeFund");

module.exports = function (deployer) {
  deployer.deploy(HedgeFund, "0x4564Ae538c0B3a5d11dD0D6780C3728bf135f7B2", 1);
};
