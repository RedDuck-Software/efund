const FundFactory = artifacts.require("FundFactory");
const Oracle = artifacts.require("UFundOracle");
const eFundERC20 = artifacts.require("eFundERC20");

module.exports = function (deployer) {
  deployer.deploy(eFundERC20).then(() => {
    eFundERC20.deployed().then((_eFundinstance) => {

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

  // deployer.deploy(Oracle).then(() => {
  //   Oracle.deployed().then((_instance) => {
  //     deployer.deploy(FundFactory, _instance.address);
  //   });
  // });
};
