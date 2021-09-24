// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Dice {

    using SafeMath for uint256;
    using SafeMath for uint8;

    /// @dev Convert random number into dice roll
    function getDice(uint256 _r) public pure returns(uint8[5] memory){
        uint8[5] memory d = [0,0,0,0,0];
        d[0] = uint8(_r.mod(6).add(1));
        d[1] = uint8(_r.div(10).mod(6).add(1)); 
        d[2] = uint8(_r.div(100).mod(6).add(1));
        d[3] = uint8(_r.div(1000).mod(6).add(1));
        d[4] = uint8(_r.div(10000).mod(6).add(1));
        require(validDice(d));
        return d;
    }

    /// @dev checks that dice are valid
    function validDice(uint8[5] memory _d) public pure returns(bool){
        uint8 t = 0;
        for(uint8 i=0;i<5;i++){
            if(_d[i] <= 0 || _d[i] > 6) { return false;}
            t = uint8(t.add(_d[i]));
        }
        return ((t > 0) && (t <= 30));
    }

    /// @dev finds matches and counts them
    function getMatches(uint8[5] memory _d) public pure returns(uint8[6] memory){
        uint8[6] memory m = [0,0,0,0,0,0];
        for (uint8 i = 0; i < _d.length; i++) { m[_d[i] - 1] = uint8(m[_d[i]-1].add(1)); }
        require(validDiceMatches(m));
        return m;
    }   

    /// @dev checks that matches are valid
    function validMatches(uint8[5] memory _d) public pure returns(bool){
        require(validDice(_d));
        uint8[6] memory m = getMatches(_d);
        return validDiceMatches(m);
    }     

    /// @dev check that values of matches are valid
    function validDiceMatches(uint8[6] memory _m) public pure returns(bool){
        uint8 cnt = 0;
        for(uint8 i=0;i<6;i++){
            if((_m[i] > 5)) { return false; }
            cnt = uint8(cnt.add(_m[i]));
        }
        //total matches should total 5 for 5 dice
        return (cnt == 5);
    }

    /// @dev sort dice
    function sort(uint8[5] memory _d) public pure returns(uint8[5] memory){
        for(uint8 i=0; i<5; i++){
            for(uint8 j=i+1; j < 5; j++){
                if(_d[i] > _d[j]){
                    uint8 x = _d[i];
                    _d[i] = _d[j];
                    _d[j] = x;
                }
            }
        }
        return _d;
    }    

    /// @dev check if dice result is all Sixes (7775 to 1)
    function isAllSixes(uint8[5] memory _d) public pure returns(bool) {       
        return ((_d[0] == 6) && (_d[1] == 6) && (_d[2] == 6) && (_d[3] == 6) && (_d[4] == 6));
    }

    /// @dev check if dice result is all Sixes (1295 to 1)
    function isFiveOfKind(uint8[5] memory _d) public pure returns(bool) {
        return ((_d[0] ==_d[1]) && (_d[0] == _d[2]) && (_d[0] == _d[3]) && (_d[0] == _d[4]));
    }    

    /// @dev check if dice result is a Four Of A Kind (51 to 1)
    function isFourOfKind(uint8[5] memory _d) public pure returns(bool){
        uint8[6] memory m = getMatches(_d);
        return ((m[0] == 4) || (m[1] == 4) || (m[2] == 4) || (m[3] == 4) || (m[4] == 4) || (m[5] == 4));
    }

    /// @dev check if dice result is a Large Straight (32 to 1)    
    function isLargeStraight(uint8[5] memory _d) public pure returns(bool){
        uint8[6] memory m = getMatches(_d);
        //12345       
        bool result = ((m[0] > 0) && (m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0));
        if(!result){ 
             //23456
            result = ((m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0) && (m[5] > 0)); 
        }
        return result;
    }      

    /// @dev check if dice result is a Full House (25 to 1)
    function isFullHouse(uint8[5] memory _d) public pure returns(bool){
        uint8[6] memory m = getMatches(_d);
        uint8[2] memory r = [0,0];
        for(uint8 i = 0;i<6;i++) {
            if(m[i] == 2){ r[0] = 1;}
            if(m[i] == 3){ r[1] = 1;}
        }
        return (r[0] == 1 && r[1] == 1);
    }     

    /// @dev check if dice result is a Small Straight (8 to 1)
    function isSmallStraight(uint8[5] memory _d) public pure returns(bool){    
        uint8[6] memory m = getMatches(_d);        
        //1234
        bool result = (m[0] > 0) && (m[1] > 0) && (m[2] > 0 ) && (m[3] > 0) && (m[4] == 0);
        if(!result){
            //2345
            result = (m[1] > 0) && (m[2] > 0) && (m[3] > 0) && (m[4] > 0);
            if(!result){
                //3456
                result = (m[2] > 0) && (m[3] > 0) && (m[4] > 0) && (m[5] > 0);
            }
        }
        return result;
    }   

    /// @dev check if dice result is a Three Of A Kind (5.5 to 1)
    function isThreeOfAKind(uint8[5] memory _d) public pure returns(bool){     
        uint8[6] memory m = getMatches(_d);
        return ((m[0] == 3) || (m[1] == 3) || (m[2] == 3) || (m[3] == 3) || (m[4] == 3) || (m[5] == 3));
    }  
    
    /// @dev check if dice result is a Small Straight (3.3 to 1)
    function isTwoPair (uint8[5] memory _d) public pure returns(bool){   
        uint8[6] memory m = getMatches(_d);
        uint8 cnt = 0;
        for(uint8 i=0;i<6;i++){ if(m[i] == 2){ cnt++; } }
        return (cnt == 2);
    }        

    /// @dev check if dice result contains a single pair
    function isSinglePair (uint8[5] memory _d) public pure returns(bool){  
        uint8[6] memory m = getMatches(_d);
        return ((m[0] == 2) || (m[1] == 2) || (m[2] == 2) || (m[3] == 2) || (m[4] == 2) || (m[5] == 2));
    }   
    
    /// @dev check if the sequence and value of two dice match
    function isMatch(uint8[5] memory _d, uint8[5] memory _d2) public pure returns(bool){    
        for(uint8 i=0;i<5;i++){ if(_d[i] != _d2[i]){ return false; } }
        return true;
    }   

    function score (
            bool _sixes, 
            bool _picks, 
            bool _custom, 
            uint[11] memory _rwd, 
            uint8[5] memory _cr,
            uint8[5] memory _di, 
            uint8[5] memory _pi
        ) 
        public pure returns (bool, uint256){
        require(validDice(_di), "_di");
              
        bool won = false;
        uint256 rwd = 0;        

        if(_sixes && isAllSixes(_di)){
            won = true;
            rwd = _rwd[1];
        } else if(!_sixes && isFiveOfKind(_di)){
            won = true;
            rwd = _rwd[0];
        }else if(_picks && validDice(_pi) && isMatch(_di, _pi)){
            won = true;
            rwd =_rwd[2];
        } else if(_custom && validDice(_cr) && isMatch(_di, _cr)){
            won = true;
            rwd =_rwd[3];
        }  

        /// @dev exit early if jackpot to skip additional scoring
        if(won){
            return (true, rwd);
        }   

        // /// @dev get token rewards index for non jackpot combinations
         if(isFourOfKind(_di)){ rwd = _rwd[4]; } 
        else if(isLargeStraight(_di)){ rwd = _rwd[5]; }  
        else if(isFullHouse(_di)){ rwd = _rwd[6]; }
        else if(isSmallStraight(_di)){ rwd = _rwd[7]; } 
        else if(isThreeOfAKind(_di)){ rwd =_rwd[8]; } 
        else if(isTwoPair(_di)){ rwd = _rwd[9]; } 
        else if(isSinglePair(_di)){ rwd = _rwd[10]; }

         return (false, rwd);
    }
}