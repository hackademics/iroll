const { assert } = require("chai");
const truffleAssert = require('truffle-assertions');
const { singletons, BN, expectEvent } = require('@openzeppelin/test-helpers');

const IRollToken = artifacts.require("IRollToken");

contract('IRollToken', async (accounts) => {
	
	let token;
	let dapp;

	let pot = accounts[1];
	let totalSupply = web3.utils.toBN('2000000000000000000000000000');
	
	//initialize and deploy contract to clean environment
	beforeEach('should setup instance', async () => {		
		this.erc1820 = await singletons.ERC1820Registry(accounts[0]);
		token = await IRollToken.deployed();		
	});

	//IROLLTOKEN
	it("should return true for token tests", async () => {		
		/*
		//get the balance of the owner, should be total supply
		const bal = await token.balanceOf.call(accounts[0]).then(async (result) => {
			assert.equal(result, 2000000000000000000000000000);
		});		

		//token name
		assert.equal(await token.name(), "IROLL.IO");

		//token symbol
		assert.equal(await token.symbol(), "IROLL");
		
		//token decimals
		assert.equal(await token.decimals(), 18);

		//token decimals
		assert.equal(await token.granularity(), 1);		
		
		//token total supply
		assert.equal(await token.totalSupply(), 2000000000000000000000000000);	

		//send too big of amount to transfer
		await truffleAssert.reverts(token.transfer(accounts[1], web3.utils.toBN('200000000000000000000000000000000')));
		
		//send zero
		await truffleAssert.reverts(token.transfer(accounts[1], web3.utils.toBN('0')));

		//send to self
		await truffleAssert.reverts(token.transfer(accounts[1], 1, { from: accounts[1] }));	
		
		//non owner tries to exceed max transfer amount
		await truffleAssert.reverts(token.transfer(accounts[0], 9999, { from: accounts[1] }));	

		//transfer one token to pot
		await token.transfer(pot, web3.utils.toBN('1'), { from: accounts[0]}).then(async () => {
			assert.equal(await token.balanceOf.call(pot), 1);
		});

		//authorize pot to send 1 token to acct 2
		await token.authorizeOperator(pot).then(async (result) => {
			assert.equal(await token.isOperatorFor.call(pot, accounts[0]), true);
			await token.transfer(accounts[2], web3.utils.toBN('1'), { from: pot }).then(async (result) => {
				assert.equal(await token.balanceOf.call(pot), 0);
				assert.equal(await token.balanceOf.call(accounts[2]), 1);
			});
		});	
		
		//transfer one token to contract
		await token.transfer(dapp.address, web3.utils.toBN('1'), { from: accounts[0]}).then(async () => {
			assert.equal(await token.balanceOf.call(dapp.address), 1);
		});	

		//transfer one token to pot
		await token.transfer(pot, web3.utils.toBN('1'), { from: accounts[0]}).then(async () => {
			assert.equal(await token.balanceOf.call(pot), 1);
		});		

		//set up dapp to be sender for pot account
		const senderHash = await dapp.senderHash();
		
		await dapp.senderFor(pot);
		await this.erc1820.setInterfaceImplementer(pot,  senderHash, dapp.address, { from: pot });
		await token.send(accounts[2], web3.utils.toBN('1'), '0x', { from: pot }).then(async () => {
			assert.equal(await token.balanceOf.call(accounts[2]), 2);
		});

		//test lock and unlock of transfers
		await token.lockTransfers().then(async () => {
			await truffleAssert.reverts(token.transfer(pot, web3.utils.toBN('1'))).then(async () =>{
				await token.unLockTransfers().then(async () => {
					await token.transfer(pot, web3.utils.toBN('1'), { from: accounts[0] }).then(async (result) => {
						assert.equal(await token.balanceOf.call(pot), 1);
					});
				});
			});
		});	*/	

		//PRINT
		//console.log("Pot:" + await token.balanceOf.call(pot));
		//console.log("[0]:" + await token.balanceOf.call(accounts[0]));
		//console.log("[2]:" + await token.balanceOf.call(accounts[2]));
		//console.log("Dapp:" + await token.balanceOf.call(dapp.address));
		//console.log("Supply:" + await token.totalSupply());			
	});
});