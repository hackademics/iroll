require('@openzeppelin/test-helpers/configure')({ provider: web3.currentProvider, environment: 'truffle' });

const { singletons } = require('@openzeppelin/test-helpers');

const Dice = artifacts.require("./contracts/library/Dice.sol");
const IRoll = artifacts.require("./contracts/IRoll.sol");
const IRollToken = artifacts.require("./contracts/token/IRollToken.sol");
const IRollVRF = artifacts.require("./contracts/token/IRollVRF.sol");

module.exports = async (deployer, network, accounts) => {  
  
  let vrfToken = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
  let vrfCoordinator = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B';
  let vrfKeyHash = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311';
  let vrfFee = (0.1 * 10 ** 18);
  let priceFeed = '0x9326BFA02ADD2366b30bacB125260Af641031331';

  /// IRoll Token Total Supply : 2 billion tokens
  let totalSupply = (2000000000 * 10 ** 18);

  /// Initial token distribution of total supply to indvidual wallets
  let distRewards    = 1000000000 * 10 ** 18; 
  let distCompany    = 400000000 * 10 ** 18;
  let distDeveloper  = 250000000 * 10 ** 18;
  let distFounder    = 250000000 * 10 ** 18;
  let distFoundation = 100000000 * 10 ** 18;

  /// vesting epochs based off midnight Sept 10th 2021 origination
  let yearOne = 1662875999;
  let yearTwo = 1694411999;
  let yearThree = 1726034399;
  let yearFour = 1757570399;

  let tokenName = "IROLL";
  let tokenSymbol = "IROLL";
  let tokenSupply = web3.utils.toBN(2000000000);

  if (network === 'development') {
    //await singletons.ERC1820Registry(accounts[0]);
  }

  //check network and deploy proper chainlink values
  if(network === 'rinkeby'){
    // RINKEBY VRF
    vrfToken = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
    vrfCoordinator = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B';
    vrfKeyHash = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311';
    vrfFee = (0.1 * 10 ** 18);
    priceFeed = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";

  } else if (network === 'arbitrumrinkeby') {
    // ARBITRUM 
    vrfToken = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
    vrfCoordinator = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B';
    vrfKeyHash = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311';
    vrfFee = (0.1 * 10 ** 18);
    _priceFeed = "0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8";

  } else if (network === 'arbitrummainnet') {
    // ARBITRUM MAIN NET
    vrfToken = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
    vrfCoordinator = '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B';
    vrfKeyHash = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311';
    vrfFee = (0.1 * 10 ** 18);
    _priceFeed = "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612";

  } else if (network === 'kovan') {
    // KOVAN VRF
    vrfToken = '0xa36085F69e2889c224210F603D836748e7dC0088';
    vrfCoordinator = '0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9';
    vrfKeyHash = '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4';
    vrfFee = (0.1 * 10 ** 18);
    _priceFeed = "0x9326BFA02ADD2366b30bacB125260Af641031331";

  } else if (network === 'mainnet') {
    // MAINNET VRF
    vrfToken = '0x514910771AF9Ca656af840dff83E8264EcF986CA';
    vrfCoordinator = '0xf0d54349aDdcf704F77AE15b96510dEA15cb7952';
    vrfKeyHash = '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311';
    vrfFee = (0.1 * 10 ** 18);
    _priceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

  } else if (network === 'polygonmumbai'){
    // POLYGON TEST VRF
    vrfToken = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB';
    vrfCoordinator = '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255';
    vrfKeyHash = '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4';
    vrfFee = (0.0001 * 10 ** 18);
    _priceFeed = "0x0715A7794a1dc8e42615F059dD6e406A6594651A";

  } else if (network === 'polygonmainnet') {
    // POLYGON MAIN VRF
    vrfToken = '0xb0897686c545045aFc77CF20eC7A532E3120E0F1';
    vrfCoordinator = '0x3d2341ADb2D31f1c5530cDC622016af293177AE0';
    vrfKeyHash = '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da';
    vrfFee = (0.0001 * 10 ** 18);
    _priceFeed = "0xDf3f72Be10d194b58B1BB56f2c4183e661cB2114";

  } else if (network === 'binancetest') {
    // BINANCE TEST VRF
    vrfToken = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB';
    vrfCoordinator = '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255';
    vrfKeyHash = '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4';
    vrfFee = (0.0001 * 10 ** 18);
    _priceFeed = "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7";
  }
  else if (network === 'binance') {
    // BINANCE VRF
    vrfToken = '0x404460C6A5EdE2D891e8297795264fDe62ADBB75';
    vrfCoordinator = '0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31';
    vrfKeyHash = '0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c';
    vrfFee = (0.2 * 10 ** 18);
    _priceFeed = "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e";
  }

  /// Deploy IROLL Token
  await deployer.deploy(IRollToken, tokenName, tokenSymbol, tokenSupply);
  
  /// get an instance of the IRollToken contract
  const token = await IRollToken.deployed();

  /// Deploy Dice.sol libarary
  await deployer.deploy(Dice);

  /// Link Dice lib to IRoll contract
  await deployer.link(Dice, IRoll);

  /// Deploy IRollVRF contract
  await deployer.deploy(IRollVRF, vrfToken, vrfCoordinator, vrfKeyHash, web3.utils.toBN(vrfFee.toString()));

  /// Get instance of IRollVRF contract
  const vrf = await IRollVRF.deployed();

  /// Deploy IRoll contract
  await deployer.deploy(IRoll, token.address, vrf.address, vrfToken, web3.utils.toBN(vrfFee.toString()), priceFeed);

  /// Get instance of IRoll contract
  const iroll = await IRoll.deployed();

  let seed = 30;
  let fee = 10;
  let interval = 1;

  let entry1 = web3.utils.toBN((0.004 * 10 ** 18));
  let entry2 = web3.utils.toBN((0.03201 * 10 ** 18));
  let entry3 = web3.utils.toBN((0.002 * 10 ** 18));
  let entry4 = web3.utils.toBN((0.2 * 10 ** 18));

  //set caller contract for vrf
  vrf.setCallerContract(iroll.address, { from: accounts[0] });

  //transfer iroll tokens to contract
  await token.transfer(iroll.address, web3.utils.toWei('1000000', "ether"), { from: accounts[0] });

  await iroll.createPot(entry1, interval, seed, fee, '0x0102030405', accounts[0], 1);
  await iroll.seedPot(1, { from: accounts[0], value: entry1 * 2 });

  /*
  await iroll.createPot(entry2, 2, 20, fee, '0x0402040204', accounts[0], 1);
  await iroll.seedPot(2, { from: accounts[0], value: entry2 * 2 });

  await iroll.createPot(entry3, 3, 25, fee, '0x0606060605', accounts[0], 1);
  await iroll.seedPot(3, { from: accounts[0], value: entry3 * 2 });

  await iroll.createPot(entry4, 4, 40, fee, '0x0504030201', accounts[0], 2);
  await iroll.seedPot(4, { from: accounts[0], value: entry4 * 2 });
  */
  
  

};
