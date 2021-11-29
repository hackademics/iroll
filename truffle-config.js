require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');
const infuraProjectID = process.env.INFURA_PROJECTID;
const etherscanApi = process.env.ETHERSCAN_API;
const dev_mnemonic = process.env.MNEMONIC;

module.exports = {

  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "5777",
      gasPrice: 100000000000,
      gas: 6721975
    },
    ropsten: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://ropsten.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 3,
      gas: 5500000,          
      timeoutBlocks: 200,  
      skipDryRun: true,
      websockets: true
     },
    rinkeby: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic},
        providerOrUrl: 'https://rinkeby.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      port: 8545,
      network_id: 4,
      gas: 4612388,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    },
    kovan: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://kovan.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 42,
      gas: 5500000,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    },
    arbitrumrinkeby: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://arbitrum-rinkeby.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 421611,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    },
    arbitrummainnet: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://arbitrum-mainnet.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 42161,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    },
    polygonmumbai: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://polygon-mumbai.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 80001,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    },
    polygonmainnet: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://polygon-mainnet.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 137,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    }, 
    mainnet: {
      provider: () => new HDWalletProvider({
        mnemonic: { phrase: dev_mnemonic },
        providerOrUrl: 'https://mainnet.infura.io/v3/' + infuraProjectID,
        numberOfAddresses: 1,
        shareNonce: true
      }),
      network_id: 1,
      port: 8545,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      websockets: true
    },
    /*binancetest: {
      provider: () => new HDWalletProvider(mnemonic, 'https://polygon-mumbai.infura.io/v3/${infuraProjectID}'),
      network_id: 97,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    binancemainnet: {
      provider: () => new HDWalletProvider(mnemonic, 'https://polygon-mainnet.infura.io/v3/${infuraProjectID}'),
      network_id: 56,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },*/
  },
  etherscan:{ apiKey: etherscanApi },
  mocha: { 
    timeout: 100000,
    reporter: 'eth-gas-reporter',
    reporterOptions: {currency: 'USD'},
  },
  compilers: {
    solc: {
       version: "0.8.7",
       docker: false,
       settings: {
        optimizer: {
          enabled: true,
          runs: 5000
        },
        metadata: { bytecodeHash: 'none' },
        evmVersion: "constantinople"
      }
    }
  },
};
