const { ethers } = require("hardhat");

async function deployOracle() { 
    const Oracle = await ethers.getContractFactory("UFundOracle");
    return await Oracle.deploy();
}

async function deployBep20() { 
    const eFundBEP20 = await ethers.getContractFactory("eFundBEP20");
    return await eFundBEP20.deploy();
}

async function deployContractFactory(bep20,oracle) { 
    const Factory = await ethers.getContractFactory("FundFactory");
    return await Factory.deploy(bep20.address,oracle.address);
}

async function main() {
    var bep20 = await deployBep20();
    console.log("eFundBEP20 deployed to: '\x1b[36m%s\x1b[0m'", bep20.address);

    var oracle = await deployOracle();
    console.log("Oracle deployed to: '\x1b[36m%s\x1b[0m'", oracle.address);

    var factory = await deployContractFactory(bep20,oracle);
    console.log("Factory deployed to: '\x1b[36m%s\x1b[0m'", factory.address);
}



  main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });