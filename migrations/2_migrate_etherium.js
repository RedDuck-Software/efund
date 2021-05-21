const FundFactory = artifacts.require("FundFactory");
const Oracle = artifacts.require("UFundOracle");
const eFundERC20 = artifacts.require("eFundERC20");

module.exports = async function (deployer) {
  await deployer.deploy(eFundERC20);
  let erc20 = eFundERC20.deployed();

  await deployer.deploy(Oracle); 
  let oracle = Oracle.deployed();

  await deployer.deploy(FundFactory, Oracle.address, eFundERC20.address); 
  let factory = FundFactory.deployed();
};
