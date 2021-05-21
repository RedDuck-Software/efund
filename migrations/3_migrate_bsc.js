const FundFactory = artifacts.require("FundFactory");
const Oracle = artifacts.require("UFundOracle");
const eFundBEP20 = artifacts.require("eFundBEP20");

module.exports = function (deployer) {
  deployer.deploy(eFundERC20).then(() => {
    eFundBEP20.deployed().then((_eFundinstance) => {

      deployer.deploy(Oracle).then(() => {
        Oracle.deployed().then((_oracleInstance) => {

          deployer.deploy(
            FundFactory,
            _instance.address,
            _eFundinstance.address
          );

        });
      });

    });
  });

};
