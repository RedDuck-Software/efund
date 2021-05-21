const FundFactory = artifacts.require("FundFactory");
const Oracle = artifacts.require("UFundOracle");
const eFundBEP20 = artifacts.require("eFundBEP20");

module.exports = async function (deployer) {
  await deployer.deploy(eFundBEP20);
  let erc20 = eFundBEP20.deployed();

  await deployer.deploy(Oracle);
  let oracle = Oracle.deployed();

  await deployer.deploy(FundFactory, Oracle.address, eFundBEP20.address);
  let factory = FundFactory.deployed();
};
