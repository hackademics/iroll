## IRoll.io 

https://iroll.io

IRollio uses Chainlink VRF to simulate a player rolling five six sided dice, scoring the results and distributing rewards based on score.

JACKPOTS:

Pot owners are able to choose from 4 different types of combonations for Jackpot wins on creation.
These settings will effect the player's odds of winning pots.

1. Five of a Kind - 5 dice result all match any number between 1-6 (i.e. [2,2,2,2,2])
2. All Sixes - 5 dice result where all die equal 6 [6,6,6,6,6]
3. Pot Dice - 5 dice result set by Pot Owner for player to match for additional jackpot win

Dice Combinations:

IROLL tokens are rewarded to players for roll combinations.

1. Four of a Kind   [1,1,1,1,5]
2. Large Straight   [1,2,3,4,5]
3. Full House       [1,1,2,2,2]
4. Small Straight   [1,2,3,4,6]
5. Three of a Kind  [1,1,1,4,5]
6. Two Pair         [1,1,3,5,6]
7. Single Pair      [1,1,4,6,3]


Pot Reward Token Array:

The token amounts won per combination are stored in an uint256[11] array assigned to every pot. This allow the pot owner adjust the tokens rewarded per pot depending on the difficulty set in winning Jackpots, entry fees and time intervals.

[10]  = Five of a Kind - JACKPOT
[9] = All Sixes - JACKPOT
[8] = Pot Dice Match - JACKPOT
[7] = Four of a Kind
[6] = Large Straight
[5] = Full House
[4] = Small Straight
[3] = Three of a Kind
[2] = Two Pair
[1] = Single Pair
[0] = No Combos

Pot Struct Parameters

UID - Unique Id for Pot based on counter
linkWallet - IRoll wallet address to use besides IRoll contract token balance for reward distribution
entry - the entry fee amount the player must pay for chance to win
interval - amount of time the player must wait between rolls in minutes
fee - percent of player jackpot payouts paid to Pot Owner
seed - percent of the Jackpot to leave behind for other players         
dice  - allow pot creator to choose roll combination for players to match
owner - Wallet Address for Pot Owner
multiplier - IROLL Rewards multiplier based on Pot settings
rewards[11] - array of token amounts to reward players for winning combinations
