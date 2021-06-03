// const HDWalletProvider = require("@truffle/hdwallet-provider");
require("@nomiclabs/hardhat-waffle");

let config = require("./secrets.json");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.6",
  networks: {
    development: {
      url: "http://127.0.0.1:8545",
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
