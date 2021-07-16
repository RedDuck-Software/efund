const { ethers } = require("hardhat");

async function deployBep20() { 
    const eFundBEP20 = await ethers.getContractFactory("eFundBEP20");
    return await eFundBEP20.deploy();
}

async function deployContractFactory() { 
    const Factory = await ethers.getContractFactory("FundFactory");
    return await Factory.deploy();
}

async function deployEFundPlatform(factory,bep20) { 
    const Platform = await ethers.getContractFactory("EFundPlatform");
    return await Platform.deploy(factory.address,bep20.address, 10000000000000000n, 100000000000000000000n);
}


async function main() {
    var bep20 = await deployBep20();
    console.log("eFundBEP20 deployed to: '\x1b[36m%s\x1b[0m'", bep20.address);

    var factory = await deployContractFactory(bep20);
    console.log("Factory deployed to: '\x1b[36m%s\x1b[0m'", factory.address);

    var platform = await deployEFundPlatform(factory,bep20);
    console.log("EFundPlatform deployed to: '\x1b[36m%s\x1b[0m'", platform.address);
}



  main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
