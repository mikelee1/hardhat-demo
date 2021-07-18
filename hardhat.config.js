require("@nomiclabs/hardhat-waffle");
require("solidity-coverage");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
// const { mnemonic } = require("./secrets.json");

//mike 如果需要统计报告
// require("hardhat-gas-reporter");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
//mike go to https://hardhat.org/guides/mainnet-forking.html

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "rinkeby",
  //mike if dont use forkmain, comment out
  //mike 和外部合约交互时，会使用forkmain
  networks: {
    hardhat: {
      forking: {
        // url: "https://eth-mainnet.alchemyapi.io/v2/lPc2RYVob1erdJsnmysPtxVt-RnRTmJm",
        // blockNumber: 12539442,
        url: "https://eth-rinkeby.alchemyapi.io/v2/9KIAF97pl17aa53vUO8w9JWkgwIyaKZZ",
        blockNumber: 8861479,
      },
      //deploy-local时，需要以下设置
      allowUnlimitedContractSize: true,
    },
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/963b685e70544ca6844c211e72193d21",
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 200000000000,
      gasLimit: 3000000,
      accounts: {
        mnemonic:
          "silk person mammal despair learn census false alter hamster clay erase quarter",
      },
      //deploy-local时，需要以下设置
      allowUnlimitedContractSize: true,
    },
  },
  solidity: {
    version: "0.7.3",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 20000,
  },
};
