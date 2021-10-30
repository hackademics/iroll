// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "../contracts/library/Dice.sol";

contract TestDice{
  
    // function testCustomRoll() public {
    //     bytes5 potDice = bytes5(0x0101010101);
    //     bytes5 dice = bytes5(0x0101010101);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice, potDice);
    //     require(d == potDice && jp && i == 10);
    // }

    // function testAllSixes() public {
    //     bytes5 dice = bytes5(0x0606060606);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && jp && i == 9);
    // }     

    // function testFiveOfAKind() public {
    //     bytes5 dice = bytes5(0x0101010101);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && jp && i == 8);
    // }   

    // function testFourOfAKind() public {
    //     bytes5 dice = bytes5(0x0606060601);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 7);
    // }             

    // function testLargeStraight() public {
    //     bytes5 dice = bytes5(0x0102030405);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 6);
    // }  

    // function testFullHouse() public {
    //     bytes5 dice = bytes5(0x0101030303);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 5);
    // } 

    // function testSmallStraight() public {
    //     bytes5 dice = bytes5(0x0102030406);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 4);
    // }     

    // function testThreeOfAKind() public {
    //     bytes5 dice = bytes5(0x0101010506);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 3);
    // }    

    // function testTwoPair() public {
    //     bytes5 dice = bytes5(0x0101020205);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 2);
    // }  

    // function testSinglePair() public {
    //     bytes5 dice = bytes5(0x0101060402);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 1);
    // }  

    // function testBupkis() public {
    //     bytes5 dice = bytes5(0x0103060502);
    //     (bytes5 d, bool jp, uint8 i) = Dice.score(dice);
    //     require(d == dice && !jp && i == 0);
    // }                            
    
}
