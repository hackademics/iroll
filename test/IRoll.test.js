const { singletons, BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require('chai');
const truffleAssert = require('truffle-assertions');

const IRoll = artifacts.require("IRoll");

contract('IRoll', async (accounts) => {
  let instance;

  beforeEach('initialize', async () => {
    instance = await IRoll.deployed();
  });

  it("should roll successfully", async () => {
    await instance.roll(1, { from: accounts[0], value: web3.utils.toBN((0.004 * 10 ** 18))}).then(async (result) => {
      console.log(result);
    });

    // await instance.test.call().then(async (result) => {
    //   console.log(result.toString());
    // });
  });
});