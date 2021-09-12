const Dice = artifacts.require("./contracts/library/Dice.sol");

module.exports = async (deployer, network, accounts) => {   
  await deployer.deploy(Dice);
};
