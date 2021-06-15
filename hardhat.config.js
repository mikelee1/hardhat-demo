require("@nomiclabs/hardhat-waffle");
require("solidity-coverage");
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
  solidity: "0.7.3",
  //mike if dont use forkmain, comment out
  //mike 和外部合约交互时，会使用forkmain
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/lPc2RYVob1erdJsnmysPtxVt-RnRTmJm",
        blockNumber: 12539442,
      },
      //deploy-local时，需要以下设置
      allowUnlimitedContractSize: true,
    },
  },
};
