const { ethers } = require("hardhat");

const { BigNumber, utils } = ethers;

async function deployERC20() { 
    const eFundERC20 = await ethers.getContractFactory("eFundERC20");
    return await eFundERC20.deploy();
}

async function deployContractFactory() { 
    const Factory = await ethers.getContractFactory("FundFactory");
    return await Factory.deploy();
}

async function deployEFundPlatform(factory,erc20, hardCap, softCap, minimalCollateral) { 
    const Platform = await ethers.getContractFactory("EFundPlatform");

    return await Platform.deploy(factory.address,erc20.address, hardCap, softCap, minimalCollateral);
}


async function main() {
    var erc20 = await deployERC20();
    console.log("eFundERC20 deployed to: '\x1b[36m%s\x1b[0m'", erc20.address);

    var factory = await deployContractFactory(erc20);
    console.log("Factory deployed to: '\x1b[36m%s\x1b[0m'", factory.address);

    // softCap = 0.1 ETH, hardCap = 100 ETH, miminalManagerCollateral = 0.5 ETH
    var platform = await deployEFundPlatform(factory,erc20, BigNumber.from('100000000000000000'), BigNumber.from('100000000000000000000'), BigNumber.from('500000000000000000'));
    console.log("EFundPlatform deployed to: '\x1b[36m%s\x1b[0m'", platform.address);
}



  main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });