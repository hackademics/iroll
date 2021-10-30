// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import { Dice } from './library/Dice.sol';
import "./IRollToken.sol";
import "./IRollVRF.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract IRoll is Ownable {
     
    struct Pot {
        uint8 seed;
        uint8 fee;
        bytes5 dice;
        address owner;
        address linkWallet;
        uint256 interval;        
        uint256 balance;           
        uint256 entry;
        uint256 UID;
    }    

    event RollInit(address indexed player, bytes32 indexed vrfid, uint256 indexed puid, uint256 nextroll);
    event Rolls(address indexed player, bytes32 indexed vrfid, uint256 indexed puid, bool jp, uint256 payout, uint256 reward, bytes5 dice); 
    event Jackpot(address indexed player, bytes32 indexed vrfid, uint256 indexed puid, bytes5 dice, uint256 payout, uint256 reward);
    event OwnerSet(address indexed ms, uint256 indexed puid, address prv, address cur);

    IRollVRF private vrf;
    IRollToken private token;
    uint256[] private pots;
    uint256 private PUID;
    bool private lock;
  
    uint256[11] private rewards = [0, 2, 3, 5, 8, 25, 32, 51, 1295, 7775, 1295]; 
  
    mapping(uint256 => Pot) pot;
    mapping(bytes32 => address) playerAddress;
    mapping(bytes32 => uint256) playerPot;
    mapping(address => uint256) playerEth;
    mapping(address => uint256) playerIRoll;
    mapping(address => mapping(uint256 => uint256)) playerNextRoll;

    constructor(address _token, address _vrf){     
        token = IRollToken(_token);
        vrf = IRollVRF(_vrf);
        PUID = 0;
    }

    function roll(uint256 _puid) public payable returns(bytes32) {       
        Pot storage p = pot[_puid];
        require((p.UID == _puid) && allowed(_puid) && (msg.value == p.entry) && (p.balance >= (p.entry*2)), "fail");

        p.balance = (p.balance + msg.value);

        bytes32 reqId = keccak256(abi.encodePacked(block.difficulty, block.timestamp));
        
        playerAddress[reqId] = msg.sender;
        playerPot[reqId] = _puid;
        playerNextRoll[msg.sender][_puid] = uint256(block.timestamp + p.interval);
 
        reqId = vrf.mockRequest(reqId);

        emit RollInit(msg.sender, reqId, playerPot[reqId], playerNextRoll[msg.sender][_puid]);

        return reqId;
    }

    function rollResponse(bytes32 requestId, uint256 _random) external {  
        Pot storage p = pot[playerPot[requestId]];           

        (bytes5 dice, bool isJackpot, uint8 rewardIndex) = Dice.score(_random, p.dice);

        uint reward = rewards[rewardIndex];
        
        if(reward > 0){
            playerIRoll[playerAddress[requestId]] = (playerIRoll[playerAddress[requestId]] + reward);
        }
        
        uint256 payout; 
        if(isJackpot){
            uint256 pSeed = ((p.balance*p.seed)/100);
            uint256 pFee = (((p.balance-pSeed)*p.fee)/100);
            payout =  ((p.balance-pSeed)-pFee);

            playerEth[playerAddress[requestId]] = (playerEth[playerAddress[requestId]] + payout);
            playerEth[p.owner] = (playerEth[p.owner] + pFee);
            p.balance = pSeed;            
        
            emit Jackpot(playerAddress[requestId], requestId, p.UID, dice, payout, reward);            
        }

        emit Rolls(playerAddress[requestId], requestId, playerPot[requestId], isJackpot, payout, reward, dice);
    }

    function allowed(uint256 _puid) public view returns(bool){
        return ((playerNextRoll[msg.sender][_puid] == 0) || (block.timestamp >= playerNextRoll[msg.sender][_puid]));     
    }

    function createPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bytes5 _dice, address _linkWallet) public returns(uint256) { 
        require(!lock, "lock");
        lock = true;
        
        PUID++;
        Pot storage p = pot[PUID];        
        p.UID = PUID;       
        p.entry = _ent;
        p.interval = uint256(_intrv * 1 minutes);
        p.seed = _seed;
        p.fee = _fee;
        p.dice = _dice;
        p.owner = owner();
        p.linkWallet = _linkWallet;
        p.balance = 0;

        pots.push(p.UID);

        lock = false;
        
        return p.UID;
    }   

    function withdraw() public {
        require(!lock, "lock");
        lock = true;
        uint256 balance = playerEth[msg.sender];
        msg.sender.transfer(balance);
        playerEth[msg.sender] = 0;
        lock = false;
    }

    function mint() public {
        require(!lock, "lock");        
        lock = true;
        uint256 balance =  playerIRoll[msg.sender];
        //token._mint(msg.sender, playerIRoll[msg.sender]);
        playerIRoll[msg.sender] = 0;
        lock = false;
    }

    function seedPot(uint256 _puid) public payable { 
        require(!lock, "lock");
        lock = true;
        pot[_puid].balance = (pot[_puid].balance + msg.value);
        lock = false;
    } 

    function getPot(uint256 _puid) public view returns(Pot memory){
        return pot[_puid];
    } 

    function getPots() public view returns(uint256[] memory){ 
        return pots;
    }   

    function getPlayerInfo() public view returns(uint256, uint256, uint256){
        return (token.balanceOf(msg.sender), playerEth[msg.sender], playerIRoll[msg.sender]);
    }

    function getPlayerNextRoll(uint256 _puid) public view returns(uint256, uint256){
        return (playerNextRoll[msg.sender][_puid], block.timestamp);
    } 

    function getRewards() public view returns(uint256[11] memory){
        return rewards;
    }     

    function setPotOwner(uint256 _puid, address _owner) public onlyOwner {
        require(!lock,"lock");
        lock = true;
        pot[_puid].owner = _owner; 
        lock = false;
    } 


    function test() public returns(bytes5){
        bytes5 a = bytes5(0x0605040302);
        bytes5 b = bytes5(0x0605040203);
        a = a[0] << 1;
        return a; 
    }
}