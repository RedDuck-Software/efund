const { ethers } = require("hardhat");

const { BigNumber, utils } = ethers;

async function deployBep20() { 
    const eFundBEP20 = await ethers.getContractFactory("eFundBEP20");
    return await eFundBEP20.deploy();
}

async function deployContractFactory() { 
    const Factory = await ethers.getContractFactory("FundFactory");
    return await Factory.deploy();
}

async function deployEFundPlatform(factory,bep20, hardCap, softCap) { 
    const Platform = await ethers.getContractFactory("EFundPlatform");
    return await Platform.deploy(factory.address,bep20.address, hardCap, softCap);
}


async function main() {
    var bep20 = await deployBep20();
    console.log("eFundBEP20 deployed to: '\x1b[36m%s\x1b[0m'", bep20.address);

    var factory = await deployContractFactory(bep20);
    console.log("Factory deployed to: '\x1b[36m%s\x1b[0m'", factory.address);

    // softCap = 0.1 BNB, hardCap = 100 BNB, miminalManagerCollateral = 0.5 BNB
    var platform = await deployEFundPlatform(factory,bep20, BigNumber.from('100000000000000000'), BigNumber.from('100000000000000000000'), BigNumber.from('500000000000000000'));
    console.log("EFundPlatform deployed to: '\x1b[36m%s\x1b[0m'", platform.address);
}


  main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });