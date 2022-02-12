require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("test", async (taskArgs, hre, runSuper) => {
  console.log("Before running the tests...");
  // your "pre-test" code here

  const result = await runSuper();

  console.log("After running the tests...");
  // your "post-test" code here

  return result;
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 * 
 *   
 * defaultNetwork: "testnet",
  networks: {
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [
        "8bacc77e9841af85a09b1eb9bc2e71b8b3f66acf8a057c89e5f1dfffe8bb4e97",
        "56584c52a2887ff9b14b3de221951ea6161d5903288b1da64bca5a182ca53f93",
        "3647e4d9aa6a5bcca05b841b1d86616f69713b42ca346b979f889252d946e3b5",
        "bde927f8301a996ff8002bab1ff7fc7c03b8dc2947e9ed87932a843c61d67bfa",
      ],
    },
  },
 */
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
            optimizerSteps: "dhfoDgvulfnTUtnIf",
          },
        },
      },
    },
  },
};
