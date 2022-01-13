// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

/// @title Dice scoring library
/// @author Richard Waldvogel
/// @notice Use this libary convert a random uint256 into an array of five bytes5 between one and six and evaluate for combinations

library Dice {

    /// @notice Convert random number into five 6 sided dice roll and score for combos
    /// @param _r Random number
    /// @param _pd Pot selected dice combo
    /// @return bytes5 represenation of the random number
    /// @return bool is the dice combo a jackpot winner
    /// @return uint8 index of the winning combo found
    function score(uint256 _r, bytes5 _pd) internal pure returns (bytes5, bool, uint8){
        bytes5 d = bytes5(abi.encodePacked(uint8((rand%6)+1), uint8(((_r/10)%6)+1), uint8(((_r/100)%6)+1), uint8(((_r/1000)%6)+1), uint8(((_r/10000)%6)+1)));
        //Is Pot Dice Match index:10
        if(d == _pd){ return (d, false, 10);}
        return score(d);
    }

    /// @notice Score a bytes5 representation of five 6-sided dice
    /// @param d Dice Array of 5 numbers between 1 and 6
    /// @return bytes5 represenation of the random number
    /// @return bool is the dice combo a jackpot winner
    /// @return uint8 index of the winning combo found
    function score(bytes5 d) internal pure returns(bytes5, bool, uint8){        
        
        // Is Five Of A Kind index:8, ex: 1-1-1-1-1
        if((d[0] == d[1]) && (d[0] == d[2]) && (d[0] == d[3]) && (d[0] == d[4])){
            //Is All Sixes index:9, ex: 6-6-6-6-6
            if(d[0] == 0x06){ return (d, true, 9); }
            return (d, true, 8);
        }        
        
        //pair count
        uint8 pc;
        //matching numbers
        uint8[6] memory m;
        //loop through numbers and find matches and count pairs
        for(uint8 i=0;i<5;i++){ 
            m[uint8(d[i])-1]++; 
            if(m[uint8(d[i])-1] == 2) { pc++; }
        }
      
        //Is Four Of A Kind index:7, ex: 1-1-1-1-6
        if(((m[0] == 4) || (m[1] == 4) || (m[2] == 4) || (m[3] == 4) || (m[4] == 4) || (m[5] == 4))){
            return (d, false, 7);
        }

        //Is Large Straight index:6, ex: 1-2-3-4-5 or 2-3-4-5-6
        if(((m[0] > 0) && (m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0)) || (m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0) && (m[5] > 0)) {
            return (d, false, 6);
        }

        //Is Full House index:5, ex: 1-1-2-2-2
        if((m[0] == 2 || m[1] == 2 || m[2] == 2 || m[3] == 2 || m[4] == 2 || m[5] == 2) && (m[0] == 3 || m[1] == 3 || m[2] == 3 || m[3] == 3 || m[4] == 3 || m[5] == 3)){
            return (d, false, 5);
        }

        //Is Small Straight index:4 ex: 1-2-3-4-6
        if(((m[0] > 0) && (m[1] > 0) && (m[2] > 0 ) && (m[3] > 0) && (m[4] == 0)) || 
            ((m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0)) || 
            ((m[2] > 0) && (m[3] > 0) && (m[4] > 0) && (m[5] > 0))){
            return (d, false, 4);
        }

        //Is Three Of A Kind index:3, ex: 1-1-1-2-5
        if(((m[0] == 3) || (m[1] == 3) || (m[2] == 3) || (m[3] == 3) || (m[4] == 3) || (m[5] == 3))){
            return (d, false, 3);
        }

        //Has Two Pairs index:2, ex: 1-1-2-2-6
        if(pc == 2){ return (d, false, 2); }

        //Has Single Pair index:1, ex: 1-1-2-6-5
        if(pc == 1){ return (d, false, 1); }

        //Return 0 for having no winning combo
        return (d, false, 0);
    }
}