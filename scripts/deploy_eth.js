const { ethers } = require("hardhat");

async function deployOracle() { 
    const Oracle = await ethers.getContractFactory("UFundOracle");
    return await Oracle.deploy();
}

async function deployErc20() { 
    const EFundERC20 = await ethers.getContractFactory("eFundERC20");
    return await EFundERC20.deploy();
}

async function deployContractFactory(erc20,oracle) { 
    const Factory = await ethers.getContractFactory("FundFactory");
    return await Factory.deploy(erc20.address,oracle.address);
}

async function main() {
    var erc20 = await deployErc20();
    console.log("eFundERC20 deployed to: '\x1b[36m%s\x1b[0m'", erc20.address);

    var oracle = await deployOracle();
    console.log("Oracle deployed to: '\x1b[36m%s\x1b[0m'", oracle.address);

    var factory = await deployContractFactory(erc20,oracle);
    console.log("Factory deployed to: '\x1b[36m%s\x1b[0m'", factory.address);
}



  main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });