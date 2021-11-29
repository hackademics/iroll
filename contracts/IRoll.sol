// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import { Dice } from './library/Dice.sol';
import "./IRollToken.sol";
import "./IRollVRF.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";

contract IRoll is Ownable, PullPayment {
     
    struct Pot {
        bool active;
        uint8 seed;
        uint8 fee;
        uint8 multiplier;
        bytes5 dice;
        address owner;
        address linkWallet;
        uint32 rolls;
        uint32 jackpots;
        uint256 linkBalance;
        uint256 interval;        
        uint256 balance;           
        uint256 entry;
        uint256 UID;
    }    

    struct Roll {
        bool complete;
        bool jackpot;
        bytes5 dice;
        uint8 combo;
        bytes32 vrfId;
        address player;
        uint256 eth;
        uint256 iroll;
        uint256 PUID;
        uint256 UID;
    }

    event RollCreated(address indexed player, bytes32 indexed vrfid, uint256 indexed puid, uint256 nextroll);
    event RollCompleted(address indexed player, bytes32 indexed vrfid, uint256 indexed ruid, uint256 puid, bool jp, uint256 payout, uint256 reward, bytes5 dice); 
    event Jackpot(address indexed player, bytes32 indexed vrfid, uint256 indexed puid, uint256 ruid, bytes5 dice, uint256 balance, uint256 seed, uint256 fee, uint256 payout);
    event OwnerSet(address indexed ms, uint256 indexed puid, address prv, address cur);

    IRollVRF private VRF;
    IRollToken private IROLL;
    LinkTokenInterface internal LINK;
    AggregatorV3Interface internal PRICEFEED;
    uint8 private networkFee;
    uint256 private PUID;
    uint256 private RUID;
    uint256 private linkFee;
    uint256 private potPrice;
    uint256[] private pots;
    uint256[] private rolls;
    bool private lock;
      
    uint256[11] private rewards = [1, 2, 3, 5, 8, 25, 32, 51, 1295, 7775, 1295]; 
  
    mapping(uint256 => Pot) s_pot;
    mapping(uint256 => Roll) s_roll;
    mapping(bytes32 => uint256) vrfRequest;
    mapping(address => uint256) irollBalance;
    mapping(address => mapping(uint256 => uint256)) nextRoll;

    constructor(address _token, address _vrf, address _link, uint256 _linkFee, address _priceFeed){             
        VRF = IRollVRF(_vrf);
        IROLL = IRollToken(_token);
        LINK = LinkTokenInterface(_link);
        PRICEFEED = AggregatorV3Interface(_priceFeed);
        PUID = 0;
        RUID = 0;
        linkFee = _linkFee;
        networkFee = 1;
    }

    function roll(uint256 _puid) public payable returns(bytes32) {    
        require(_puid > 0, "bad potid");   
        Pot storage p = s_pot[_puid];
        require((p.UID == _puid) && p.active, "bad pot");
        require(allowed(_puid), "bad interval");
        require((msg.value == p.entry) && (p.balance >= (p.entry*2)), "bad entrybal");

        //add entry to pot balance
        p.balance = (p.balance + msg.value);
        //set interval for players next pot roll
        nextRoll[msg.sender][_puid] = uint256(block.timestamp + p.interval);

        RUID++;
        Roll storage r = s_roll[RUID];        
        r.UID = RUID;
        r.PUID = p.UID;
        r.player = msg.sender; 
        
        //bytes32 reqId = VRF.request();
        bytes32 reqId = keccak256(abi.encodePacked(block.difficulty, block.timestamp));
        vrfRequest[reqId] = r.UID;
        r.vrfId = reqId;  
        reqId = VRF.mockRequest(reqId);

        rolls.push(r.UID);

        emit RollCreated(msg.sender, reqId, r.PUID, nextRoll[msg.sender][_puid]);

        return reqId;
    }

    function rollResponse(bytes32 _requestId, uint256 _random) external {  
        require(msg.sender == address(VRF) && _requestId != 0 && _random > 0, "bad vrf");   
        uint256 rollId = vrfRequest[_requestId];
        require(rollId > 0, "bad current roll");               
        Roll storage r = s_roll[rollId];
        require(r.vrfId == _requestId && r.complete == false, "bad roll");
        Pot storage p = s_pot[r.PUID];  
        require(p.UID == r.PUID && p.active, "bad pot");

        //convert and score dice
        (bytes5 dice, bool isJackpot, uint8 rewardIndex) = Dice.score(_random, p.dice);

        //escrow combo reward tokens
        uint reward = (rewards[rewardIndex] * p.multiplier);        
        irollBalance[r.player] = (irollBalance[r.player] + reward);
        
        uint256 payout; 
        if(isJackpot){
            uint256 pBalance = p.balance;
            uint256 pSeed = ((pBalance*p.seed)/100);
            uint256 pFee = (((pBalance-pSeed)*p.fee)/100);
            payout = ((pBalance-pSeed)-pFee);

            uint256 playerFee = ((payout*networkFee)/100);
            payout = (payout -  playerFee); 

            uint256 ownerFee = ((pFee*networkFee)/100);
            pFee = (pFee - ownerFee);

            //pay player
            _asyncTransfer(r.player, payout);

            //pay pot owner
            _asyncTransfer(p.owner, pFee);

            //pay owner
            _asyncTransfer(owner(), (playerFee + ownerFee));            

            p.balance = pSeed; 
            p.jackpots++;           
        
            emit Jackpot(r.player, _requestId, p.UID, r.UID, dice, pBalance, pSeed, pFee, payout);            
        }

        p.rolls++;
        r.combo = rewardIndex;
        r.dice = dice;
        r.eth = payout;
        r.iroll = reward;
        r.jackpot = isJackpot;
        r.complete = true;

        emit RollCompleted(r.player, r.vrfId, r.PUID, r.UID, r.jackpot, r.eth, r.iroll, r.dice);
    }

    function allowed(uint256 _puid) public view returns(bool){
        return ((nextRoll[msg.sender][_puid] == 0) || (block.timestamp >= nextRoll[msg.sender][_puid]));     
    }

    function withdrawTokens() public {
        require(!lock, "lock");        
        lock = true;
        uint256 bal = irollBalance[msg.sender];
        if(bal > 0){
            IROLL.transfer(msg.sender, bal);
            irollBalance[msg.sender] = 0;
        }
        lock = false;
    }

    function seedPot(uint256 _puid) public payable returns(uint256) { 
        require(!lock, "lock");
        lock = true;
        s_pot[_puid].balance = (s_pot[_puid].balance + msg.value);
        lock = false;

        return s_pot[_puid].balance;
    } 

    function getTokenBalance() public view returns(uint256){
        return IROLL.balanceOf(address(this));
    }

    function getPotCount() public view returns(uint256){
        return pots.length;
    }

    function getPotRewards(uint256 _puid) public view returns(uint256[11] memory){
        Pot storage p = s_pot[_puid];
        require(p.active, "bad pot");        
        if(p.multiplier > 1){
            uint8 m = p.multiplier;
            return [rewards[0]*m, rewards[1]*m, rewards[2]*m, rewards[3]*m, rewards[4]*m, rewards[5]*m, rewards[6]*m, rewards[7]*m, rewards[8]*m, rewards[9]*m, rewards[10]*m];
        }
        return rewards;
    }      

    function getPot(uint256 _puid) public view returns(Pot memory){
        return s_pot[_puid];
    } 

    function getPots() public view returns(uint256[] memory){ 
        return pots;
    } 

    function getPotBalance(uint256 _puid) public view returns(uint256){
        return s_pot[_puid].balance;
    }     

    function getRollCount() public view returns(uint256){
        return rolls.length;
    } 

    function getRoll(uint256 _ruid) public view returns(Roll memory){
        return s_roll[_ruid];
    }

    function getPotRolls(uint256 _puid) public view returns(Roll[] memory){
        Roll[] memory r = new Roll[](rolls.length);
        for(uint i = 0;i < rolls.length; i++){
            if(s_roll[i].PUID == _puid){
                r[i] = s_roll[i];
            }
            if(i > 200){break;}
        }
        return r;
    }

    function getPlayerRolls(address _player) public view returns(Roll[] memory){
        Roll[] memory r = new Roll[](rolls.length);
        for(uint i = 0;i < rolls.length; i++){
            if(s_roll[i].player == _player){
                r[i] = s_roll[i];
            }
            if(i > 200){break;}
        }
        return r;
    }    

    function getPlayerTokenBalance() public view returns(uint256){
        return IROLL.balanceOf(msg.sender);
    } 

    function getPlayerEthBalance() public view returns(uint256){
        return payments(msg.sender);
    }

    function getPlayerNextRoll(uint256 _puid) public view returns(uint256, uint256){
        return (nextRoll[msg.sender][_puid], block.timestamp);
    } 

    function getRewards() public view returns(uint256[11] memory){
        return rewards;
    }  

    function depositPotLink(uint256 _puid, uint256 _amount) external returns(uint256){
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        require(LINK.transferFrom(msg.sender, address(this), _amount), "bad transfer");
        p.linkBalance = (p.linkBalance + _amount);
        return p.linkBalance;
    }   

    function approvePotLink(uint256 _puid, uint256 _amount) public {
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        LINK.approve(p.linkWallet, _amount);
    } 

    function getPotLinkBalance(uint256 _puid) public view returns(uint256) {
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        return p.linkBalance;
    }

    function setPotMultiplier(uint256 _puid, uint8 _multiplier) public onlyOwner returns(uint256) {
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        p.multiplier = _multiplier;
        return p.multiplier;
    }    

    function setPotLinkWallet(uint256 _puid, address _linkWallet) public {
        Pot storage p = s_pot[_puid];
        require(p.active && (msg.sender == p.owner || msg.sender == owner()), "bad request");
        p.linkWallet = _linkWallet;
    }    

    function setPotOwner(uint256 _puid, address _owner) public onlyOwner{
        require(!lock,"lock");
        lock = true;
        s_pot[_puid].owner = _owner; 
        lock = false;
    } 

    function setLinkFee(uint256 _linkFee) public onlyOwner{
        require(_linkFee > 0, "bad fee");
        linkFee = _linkFee;
    } 

    function setPotPrice(uint256 _price) public onlyOwner{
        require(_price > 0, "bad price");
        potPrice = _price;
    }

    function closePot(uint256 _puid) public onlyOwner {
        require(!lock,"lock");
        lock = true;
        Pot storage p = s_pot[_puid];
        require(p.UID == _puid && p.active && p.balance > 0, "bad request");
        _asyncTransfer(p.owner, p.balance);
        p.balance = 0;
        p.active = false;
        lock = false;
    }

    function buyPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bytes5 _dice, address _linkWallet) public payable returns(uint256){
        require(msg.value == potPrice,"bad price");
        return addPot(_ent, _intrv, _seed, _fee, _dice, _linkWallet, 1);
    }

    function createPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bytes5 _dice, address _linkWallet, uint8 _multiplier) public onlyOwner returns(uint256) { 
       return addPot(_ent, _intrv, _seed, _fee, _dice, _linkWallet, _multiplier);
    } 

    function addPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bytes5 _dice, address _linkWallet, uint8 _multiplier) private returns(uint256){
        require(!lock, "lock");
        lock = true;
        
        PUID++;
        Pot storage p = s_pot[PUID];        
        p.UID = PUID;       
        p.entry = _ent;
        p.interval = uint256(_intrv * 1 minutes);
        p.seed = _seed;
        p.fee = _fee;
        p.dice = _dice;
        p.owner = owner();
        p.linkWallet = _linkWallet;
        p.balance = 0;
        p.rolls = 0;
        p.jackpots = 0;
        p.active = true;
        p.multiplier = _multiplier;

        pots.push(p.UID);

        lock = false;
        
        return p.UID;        
    }

    function getCurrentEthPrice() public view returns (int) {
        (,int price,,,) = PRICEFEED.latestRoundData();
        return price;
    }    
}