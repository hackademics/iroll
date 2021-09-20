const { singletons, BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require('chai');
const truffleAssert = require('truffle-assertions');

const IRollToken = artifacts.require("IRollToken");
const IRoll = artifacts.require("IRoll");

contract('IRoll', async (accounts) => {
  let token;
  let instance;

  /// pot parameters
  let wallet = accounts[1];
  let entry = web3.utils.toBN(.002 * 10 ** 18);
  let seed = 30;
  let fee = 10;
  let interval = 1;
  let sixes = 0;
  let picks = 0;
  let custom = 0;
  let rewards = [256, 512, 256, 256, 128, 64, 32, 16, 8, 4, 2];
  let customRoll = [1, 1, 1, 1, 1];
  let playerPicks = [1, 2, 3, 4, 5];

  let invalidCustomRoll = [0, 7, 8, 9, 10];  
  let invalidPlayerPicks = [1, 2, 3, 4, 0];

  beforeEach('initialize', async () => {
    token = await IRollToken.deployed();
    instance = await IRoll.deployed();
    this.erc1820 = await singletons.ERC1820Registry(accounts[0]);
  });


  // it("check that contract balance is zero", async() =>{
  //   assert.equal(await token.balanceOf.call(instance.address), 0);
  // });

  // it("transfer reward tokens to contract", async () => {
  //     await token.transfer(instance.address, web3.utils.toBN(1), { from: accounts[0] }).then(async (result) => {
  //       assert.equal(await token.balanceOf.call(instance.address), 1);
  //     });
  // });

  // it("roll reverts because no pots exist yet", async () => {
  //   await truffleAssert.reverts(instance.roll(web3.utils.toBN(1), playerPicks, { from: accounts[0], value: 0 }), "revert 404");
  // });

  // it("creates a new pot", async () => {
  //   await instance.createPot(wallet, entry, interval, seed, fee, sixes, picks, custom, customRoll, rewards)
  //         .then(async (result) => {
  //           assert.equal(result.receipt.status, true);
  //         });
  // });

  // it("get single pot by UID confirm balance is zero", async () => {
  //   await instance.getPot(web3.utils.toBN(1)).then(async (result) => {
  //     assert.equal(result.balance, 0);
  //   });
  // });

  // it("seed selected pot with insufficient seed", async () => {
  //   await instance.seedPot(web3.utils.toBN(1), { from: accounts[0], value: entry }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("roll reverts because selected pot not seeded enough", async () => {
  //   await truffleAssert.reverts(instance.roll(web3.utils.toBN(1), playerPicks, { from: accounts[0], value: entry }), "seed");
  // });

  // it("seed selected pot with 20 times the entry fee", async () => {
  //   await instance.seedPot(web3.utils.toBN(web3.utils.toBN(1)), { from: accounts[0], value: web3.utils.toBN((entry * 20)) }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("verify pot balance equal to two previous seeds", async () => {
  //   await instance.getPotBalance(1).then(async (result) => {
  //     assert.equal(web3.utils.fromWei(result, 'ether'), 0.042);
  //   });
  // });

  // it("roll reverts because invalid entry fee", async () => {
  //   await truffleAssert.reverts(instance.roll(1, playerPicks, { from: accounts[0], value: 0 }), "fee");
  // });

  // it("pause contract", async () => {
  //   await instance.pause().then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("roll reverts because contract is paused", async () => {
  //   await truffleAssert.reverts(instance.roll(1, playerPicks, { from: accounts[0], value: entry }));
  // });

  // it("unpause contract", async () => {
  //   await instance.unpause().then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("set pot to inactive", async () => {
  //   await instance.setPotActive(web3.utils.toBN(1), false).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("getpot should revert due to pot being inactive", async () => {
  //   await truffleAssert.reverts(instance.getPot(web3.utils.toBN(1)), "revert 404");
  // });

  // it("set pot to active", async () => {
  //   await instance.setPotActive(web3.utils.toBN(1), true).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("initiates roll and is successful in getting back vrfrequest id", async () => {
  //   await instance.roll(web3.utils.toBN(1), playerPicks, { from: accounts[0], value: web3.utils.toBN(entry) }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("test pay jackpot then get payments balance then withdraw", async () => {
  //   await instance.testPay(1).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("check pull payment balance", async () => {
  //   await instance.payments(accounts[0]).then(async (result) => {
  //     assert.equal(web3.utils.fromWei(result, 'ether'), 0.0294);
  //   });
  // });

  // it("player withdraws balance", async () => {
  //   await instance.withdrawPayments(accounts[0]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // //it("get single roll by UID", async () => {
  //   //await instance.getRoll(1).then(async (result) => {
  //     //console.log(result.PUID, 1);
  //   //});
  // //});

  // it("get list of all rolls", async () => {
  //   await instance.getRolls().then(async (result) => {
  //     assert.equal(result.length, 1);
  //   });
  // });

  // it("all sixes creation", async () => {
  //   await instance.createPot(wallet, entry, interval, seed, fee, 1, 0, 0, customRoll, rewards).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("all sixes seed with 4 times the entry fee", async () => {
  //   await instance.seedPot(2, { from: accounts[0], value: (entry * 4) }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("all sixes test scoring", async () => {
  //   let allsix = [6, 6, 6, 6, 6];
  //   await instance.testScore.call(2, allsix, playerPicks).then(async (result) => {
  //     assert.equal(result[0], true);
  //     assert.equal(result[1], rewards[1]);
  //   });
  // });

  // it("all sixes test pay", async () => {
  //   await instance.testPay(2).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("all sixes check players balance", async () => {
  //   await instance.payments(accounts[0]).then(async (result) => {
  //     //console.log(result.toString());
  //     assert.equal(result, 5600000000000000);
  //   });
  // });

  // it("all sixes player withdraws balance", async () => {
  //   await instance.withdrawPayments(accounts[0]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("player pick pot creation ", async () => {
  //   await instance.createPot(wallet, entry, interval, seed, fee, 0, 1, 0, customRoll, rewards).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("player pick seed with 4 times the entry fee", async () => {
  //   await instance.seedPot(3, { from: accounts[0], value: (entry * 4) }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("player pick roll gets vrfrequest id", async () => {
  //   await instance.roll(3, playerPicks, { from: accounts[0], value: entry }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("player pick test scoring", async () => {
  //   let pp = [5, 5, 1, 5, 5];
  //   await instance.testScore.call(3, playerPicks, playerPicks).then(async (result) => {
  //     assert.equal(result[0], true);
  //     assert.equal(result[1], rewards[0]);
  //   });
  // });

  // it("player pick test pay", async () => {
  //   await instance.testPay(3).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("player pick check players balance", async () => {
  //   await instance.payments.call(accounts[0]).then(async (result) => {
  //     //console.log(result.toString());
  //     assert.equal(result, 5600000000000000);
  //   });
  // });

  // it("player pick player withdraws balance", async () => {
  //   await instance.withdrawPayments(accounts[0]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("custom roll pot creation ", async () => {
  //   await instance.createPot(wallet, entry, interval, seed, fee, 0, 0, 1, customRoll, rewards).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("custom roll seed with 4 times the entry fee", async () => {
  //   await instance.seedPot(4, { from: accounts[0], value: (entry * 4) }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("custom roll gets vrfrequest id", async () => {
  //   await instance.roll(4, playerPicks, { from: accounts[0], value: entry }).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("custom roll test scoring", async () => {
  //   await instance.testScore.call(4, customRoll, playerPicks).then(async (result) => {
  //     assert.equal(result[0], true);
  //     assert.equal(result[1], rewards[0]);
  //   });
  // });

  // it("custom roll test pay", async () => {
  //   await instance.testPay(4).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("custom roll check players balance", async () => {
  //   await instance.payments.call(accounts[0]).then(async (result) => {
  //     //console.log(result.toString());
  //     assert.equal(result, 5600000000000000);
  //   });
  // });

  // it("custom roll player withdraws balance", async () => {
  //   await instance.withdrawPayments(accounts[0]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("change first pot owner to accounts 1", async () => {
  //   await instance.setPotOwner(1, accounts[1]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("update pot current roll", async () => {
  //   await instance.setPotRoll(1, [6, 5, 4, 3, 2]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("update pot wallet", async () => {
  //   await instance.setPotWallet(1, accounts[1]).then(async (result) => {
  //     assert.equal(result.receipt.status, true);
  //   });
  // });

  // it("roll reverts because it exceeds the pot wait interval", async () => {
  //   await truffleAssert.reverts(instance.roll(1, playerPicks, { from: accounts[0], value: entry }), "wait");
  // });

  it("tests for one pair", async () => {
    let onepair = [1, 1, 2, 3, 6];
    await instance.testScore.call(1, onepair, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[10]);
    });
  });

  it("tests for two pair", async () => {
    let twopair = [1, 1, 2, 2, 6];
    await instance.testScore.call(1, twopair, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[9]);
    });
  });

  it("tests for three of a kind", async () => {
    let threeoak = [1, 1, 1, 2, 6];
    await instance.testScore.call(1, threeoak, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[8]);
    });
  });

  it("tests for small straight", async () => {
    let smst = [1, 2, 3, 5, 6];
    await instance.testScore.call(1, smst, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], 0);
    });

    smst = [1, 2, 3, 4, 6];
    await instance.testScore.call(1, smst, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[7]);
    });

    smst = [3, 4, 5, 6, 1];
    await instance.testScore.call(1, smst, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[7]);
    });

    smst = [6, 5, 4, 3, 1];
    await instance.testScore.call(1, smst, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[7]);
    });
  });

  it("tests for full house", async () => {
    let fh = [1, 1, 2, 2, 2];
    await instance.testScore.call(1, fh, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[6]);
    });
  });

  it("tests for large straight", async () => {
    let lg = [1, 2, 3, 4, 5];
    await instance.testScore.call(1, lg, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[5]);
    });

    let lg2 = [2, 3, 4, 5, 6];
    await instance.testScore.call(1, lg2, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[5]);
    });
  });

  it("tests for four of a kind", async () => {
    let foak = [1, 1, 1, 1, 5];
    await instance.testScore.call(1, foak, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], false);
      assert.equal(result[1], rewards[4]);
    });
  });

  it("tests for jackpot five of a kind", async () => {
    let jp = [1, 1, 1, 1, 1];
    await instance.testScore.call(1, jp, playerPicks).then(async (result) => {
      console.log(result[1].toString());
      assert.equal(result[0], true);
      assert.equal(result[1], rewards[0]);
    });
  });


});