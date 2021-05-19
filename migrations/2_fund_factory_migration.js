const FundFactory = artifacts.require("FundFactory");
const Oracle = artifacts.require("UFundOracle");

module.exports = function (deployer) {
  deployer.deploy(Oracle).then(() => {
    Oracle.deployed().then((_instance) => {
      deployer.deploy(FundFactory, _instance.address);
    });
  });
};
