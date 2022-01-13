## IROLL BLOCKCHAIN DICE GAME

https://iroll.io - (coming soon)

IRoll uses Chainlink VRF to simulate a player rolling five 6-sided dice, scoring the results and distributing rewards to players.  Gameplay is based on a classic midwest tavern dice game, commonly referred to as "Shake A Day".  Patrons are allowed one opportunity per day to purchase rolling five 6-sided dice.  Entry Fees are pooled into the Pot balance and accumlate until a player rolls a JACKPOT.  A percent or minimum balance is deducted from JACKPOT winnings to fund future play.

IRoll.io is an interpatation of this simple dice game. 

Players connect their wallet to the IRoll contract and pay an entry fee in ETH.  Entry Fees pooled into the balance of the selected Pot.  VRF random numbers are requested and converted to representation of five 6-sided dice. The dice values are then scored using a Dice library to determine JACKPOTS and IROLL rewards. JACKPOT winnings are calculated using each unique set of Pot rules. Rolls are recorded for auditing to ensure fair play.

## CONTRACTS

IRoll.sol - Main application logic to request VRF random numbers and the Chainlink response.  Pot management.  Payout transfers. roll(uint256 _puid) is app entry method.

IRollToken.sol - IROLL ERC-20 Token for player rewards.  

IRollVRF.sol - Chainklink VRF Wrapper for random number requests and responses

## LIBRARIES

Dice.sol - Converts random number to five 6-sided dice and scores it for combos

## MIGRATIONS

2_irolltoken_iroll_migration.js - Main logic used by Truffle to migrate code to a specific EVM network.  Default parameters are passed to contract constructors to initialize variables.

## DICE

The VRF random number is converted to five numbers between 1 and 6 using a modulus operation.

ex: uint8(((_randomNumber/100)%6)+1)

The numbers are then encoded to a bytes5 value for minimal storage. 

ex: 0x0101010405

## JACKPOTS

Pot owners are able to choose from 4 different types of combonations for Jackpot wins on creation.
These settings will effect the player's odds of winning pots.

- Five of a Kind - Five 6-sided dice result all match any number between 1-6 (i.e. [2,2,2,2,2])
- All Sixes - Five 6-sided dice result where all die equal 6 [6,6,6,6,6]
- Pot Dice - Five 6-sided dice result set by Pot Owner for player to match for additional jackpot win

## PAYOUTS

Pot Balance - (Pot Seed Percent - Pot Fee Percent)   

- uint256 pBalance = Pot.balance;
- uint256 pSeed = ((pBalance*p.seed)/100);
- uint256 pFee = (((pBalance-pSeed)*p.fee)/100);
- uint256 payout = ((pBalance-pSeed)-pFee);

Pot settings for Seed and Fee should not change after game play has started.

OpenZeppelin PullPayment contract used to store JACKPOT payouts to player escrow for future withdrawal.

Network Fees and Pot Owner commissions are used to pay for VRF requests and seed Pots.

## FIVE 6-SIDED DICE SCORING:

IROLL tokens are rewarded to players for the additional combinations.

- Four of a Kind   [1,1,1,1,5]
-  Large Straight   [1,2,3,4,5]
-  Full House       [1,1,2,2,2]
-  Small Straight   [1,2,3,4,6]
-  Three of a Kind  [1,1,1,4,5]
-  Two Pair         [1,1,3,5,6]
-  Single Pair      [1,1,4,6,3]


## IROLL TOKEN REWARDS

The token amounts won per combination are stored in an uint256[11] array assigned to every pot. This allow the pot owner adjust the tokens rewarded per pot depending on the difficulty set in winning Jackpots, entry fees and time intervals.

- [10] = Five of a Kind - JACKPOT
- [9] = All Sixes - JACKPOT
- [8] = Pot Dice Match - JACKPOT
- [7] = Four of a Kind
- [6] = Large Straight
- [5] = Full House
- [4] = Small Straight
- [3] = Three of a Kind
- [2] = Two Pair
- [1] = Single Pair
- [0] = No Combo (aka Bupkis)

## POT STRUCT PARAMETERS

- bool active - Is Pot active and open to players;
- uint8 seed - Amount of Pot balance to leave for next players
- uint8 fee - Amount paid to Pot Owner
- uint8 multiplier - Amount to increase base IROLL reward
- bytes5 dice - Five 6-sided dice combo for player to match for JACKPOT
- address owner - Pot Owner
- address linkWallet - LINK token wallet address
- uint32 rolls - Array of VRF Request Ids made for Pot
- uint32 jackpots - Total amount of JACKPOTS won
- uint256 linkBalance - LINK Token balance to pay for VRF requests
- uint256 interval - Amount of time players must wait between rolls 
- uint256 balance - Amount ETH Pot 
- uint256 entry - Entry Fee to be transferred to Pot balance  
- uint256 UID - Pot Unique Id


## ROLL STRUCT PARAMETERS

- bool complete - Is roll lifecycle complete
- bool jackpot - Is roll result JACKPOT 
- bytes5 dice - Five 6-sided dice from random number
- uint8 combo - Index of the dice combo match during scoring
- bytes32 vrfId - VRF Request Id
- address player - Owner of Roll
- uint256 eth - Amount of ETH won
- uint256 iroll - Amount of IROLL won
- uint256 PUID - Pot Unique Id
- uint256 UID - Roll Unique Id

## IROLL ERC-20 REWARD TOKEN

Reward players who score dice combos 

- IROLL - symbol
- IROLL.IO - name
- 1.0 - version
- 2,000,000,000 - total supply

Deployed Token Addresses

- MAINNET - TBD
- RINKEBY - TBD
- POLYGON - TBD
- ARBITRUM - TBD

## USER INTERFACE

Under Development