// const HDWalletProvider = require("@truffle/hdwallet-provider");
require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');

let config = require("./secrets.json");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.6.6",
    settings: {
      optimizer: { 
        enabled: true, 
        runs: 1000 
      } 
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    development: {
      url: "http://127.0.0.1:8545",
      gas: 8272652
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${config.projectId}`,
      accounts: {
        mnemonic: config.mnemonic,
      },
      chainId: 4,
      gas: 1230000,
    },

    kovan: {
      url: `https://kovan.infura.io/v3/${config.projectId}`,
      accounts: {
        mnemonic: config.mnemonic,
      },
      chainId: 42,
      gas: 1230000,
    },
    bscTestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      accounts: {
        mnemonic: config.mnemonic,
      },
      chainId: 97,
      gas: 1230000,
    },
  },
};
