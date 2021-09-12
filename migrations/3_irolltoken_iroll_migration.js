require('@openzeppelin/test-helpers/configure')({ provider: web3.currentProvider, environment: 'truffle' });

const { singletons } = require('@openzeppelin/test-helpers');

const Dice = artifacts.require("./contracts/library/Dice.sol");
const IRoll = artifacts.require("./contracts/IRoll.sol");
const IRollToken = artifacts.require("./contracts/token/IRollToken.sol");

const IRollRNG = artifacts.require("./contracts/chainlink/IRollRNG.sol");

module.exports = async (deployer, network, accounts) => {  
  
    let vrfToken = '0x514910771AF9Ca656af840dff83E8264EcF986CA';
    let vrfCoordinator = '0xf0d54349aDdcf704F77AE15b96510dEA15cb7952';
    let vrfKeyHash = '0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445';
    let vrfFee = 2;

  if (network === 'development') {
    await singletons.ERC1820Registry(accounts[0]);
  }

  //check network and deploy proper chainlink values
  if(network === 'rinkeby'){
    // RINKEBY VRF
    vrfToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    vrfCoordinator = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    vrfKeyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    vrfFee = (0.1 * 10 ** 18);

  } else if (network === 'rinkarby') {
    // ARBITRUM 
    vrfToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    vrfCoordinator = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    vrfKeyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    vrfFee = (0.1 * 10 ** 18);

  } else if (network === 'arbitrum') {
    // ARBITRUM 
    vrfToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    vrfCoordinator = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    vrfKeyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    vrfFee = (0.1 * 10 ** 18);

  } else if (network === 'kovan') {
    // RINKEBY VRF
    vrfToken = 0xa36085F69e2889c224210F603D836748e7dC0088;
    vrfCoordinator = 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9;
    vrfKeyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    vrfFee = (2 * 10 ** 18);

  } else if (network === 'mainnet') {
    // MAINNET VRF
    vrfToken = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    vrfCoordinator = 0xf0d54349aDdcf704F77AE15b96510dEA15cb7952;
    vrfKeyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    vrfFee = (0.1 * 10 ** 18);

  } else if (network === 'polygontest'){
    // POLYGON TEST VRF
    vrfToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    vrfCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
    vrfKeyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
    vrfFee = (0.0001 * 10 ** 18);

  } else if (network === 'polygonmain') {
    // POLYGON MAIN VRF
    vrfToken = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
    vrfCoordinator = 0x3d2341ADb2D31f1c5530cDC622016af293177AE0;
    vrfKeyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
    vrfFee = (0.0001 * 10 ** 18);

  } else if (network === 'binancetest') {
    // BINANCE TEST VRF
    vrfToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    vrfCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
    vrfKeyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
    vrfFee = (0.0001 * 10 ** 18);

  }
  else if (network === 'binance') {
    // BINANCE VRF
    vrfToken = 0x404460C6A5EdE2D891e8297795264fDe62ADBB75;
    vrfCoordinator = 0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31;
    vrfKeyHash = 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c;
    vrfFee = (0.2 * 10 ** 18);
  }
  
  await deployer.deploy(IRollToken);
  const token = await IRollToken.deployed();

  await deployer.deploy(Dice);
  await deployer.link(Dice, IRoll);

  await deployer.deploy(IRoll, token.address, vrfToken, vrfCoordinator);
  const iroll = await IRoll.deployed();

  await deployer.deploy(IRollRNG, vrfToken, vrfCoordinator);
  const rng = await IRollRNG.deployed();

  rng.setKeyHash(vrfKeyHash);
  rng.setFee(vrfFee);
  rng.setCallerContract(iroll.address);

};
