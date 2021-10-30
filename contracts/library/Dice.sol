// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

library Dice {


    function score(uint256 _r, bytes5 pd) internal pure returns (bytes5, bool, uint8){
        bytes5 d = bytes5(abi.encodePacked(uint8((_r%6)+1), uint8(((_r/10)%6)+1), uint8(((_r/100)%6)+1), uint8(((_r/1000)%6)+1), uint8(((_r/10000)%6)+1)));
        if(d == pd){ return (d, false, 10);}
        return score(d);
    }

    function score(bytes5 d) internal pure returns(bytes5, bool, uint8){        
        
        //five of a kind
        if((d[0] == d[1]) && (d[0] == d[2]) && (d[0] == d[3]) && (d[0] == d[4])){
            //all sixes
            if(d[0] == 0x06){ return (d, true, 9); }
            return (d, true, 8);
        }

        //pair count
        uint8 pc;
        //matches
        uint8[6] memory m;
        for(uint8 i=0;i<5;i++){ 
            m[uint8(d[i])-1]++; 
            if(m[uint8(d[i])-1] == 2) { pc++; }
        }
      
        // //four of kind
        if(((m[0] == 4) || (m[1] == 4) || (m[2] == 4) || (m[3] == 4) || (m[4] == 4) || (m[5] == 4))){
            return (d, false, 7);
        }

        // //large straight
        if(((m[0] > 0) && (m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0)) || (m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0) && (m[5] > 0)) {
            return (d, false, 6);
        }

        // //full house
        if((m[0] == 2 || m[1] == 2 || m[2] == 2 || m[3] == 2 || m[4] == 2 || m[5] == 2) && (m[0] == 3 || m[1] == 3 || m[2] == 3 || m[3] == 3 || m[4] == 3 || m[5] == 3)){
            return (d, false, 5);
        }

        // //small straight
        if(((m[0] > 0) && (m[1] > 0) && (m[2] > 0 ) && (m[3] > 0) && (m[4] == 0)) || 
            ((m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0)) || 
            ((m[2] > 0) && (m[3] > 0) && (m[4] > 0) && (m[5] > 0))){
            return (d, false, 4);
        }

        // //three of a kind
        if(((m[0] == 3) || (m[1] == 3) || (m[2] == 3) || (m[3] == 3) || (m[4] == 3) || (m[5] == 3))){
            return (d, false, 3);
        }

        //two pair
        if(pc == 2){ return (d, false, 2); }

        //single pair
        if(pc == 1){ return (d, false, 1); }

        //bupkis
        return (d, false, 0);
    }
}