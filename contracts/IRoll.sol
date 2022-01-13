// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import { Dice } from './library/Dice.sol';
import "./IRollToken.sol";
import "./IRollVRF.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";

/// @title IRoll - pay entry for chance to win percent of pot
/// @author Richard Waldvogel
/// @notice 
contract IRoll is Ownable, PullPayment {
     
    /// @notice Pot parameters
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

    /// @notice Record for each player roll lifecycle
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
    event RollCompleted(address indexed player, bytes32 indexed vrfid, uint256 indexed ruid, uint256 puid, bool jp, uint256 payout, uint256 reward, bytes5 dice, uint8 rewardIndex); 
    event Jackpot(address indexed player, bytes32 indexed vrfid, uint256 indexed puid, uint256 ruid, bytes5 dice, uint256 balance, uint256 seed, uint256 fee, uint256 payout);
    event OwnerSet(address indexed ms, uint256 indexed puid, address prv, address cur);

    IRollVRF private VRF;
    IRollToken private IROLL;
    LinkTokenInterface internal LINK;
    AggregatorV3Interface internal PRICEFEED;
    
    bool private lock;
    uint8 private networkFee;
    uint256 private PUID;
    uint256 private RUID;
    uint256 private linkFee;
    uint256 private potPrice;
    uint256[] private pots;
    uint256[] private rolls;    
    
    /// @dev Array of the amount of IROLL to reward for combos based on odds for combo
    uint256[11] private rewards = [1, 2, 3, 5, 8, 25, 32, 51, 1295, 7775, 1295]; 
  
    /// @dev Data Storage
    mapping(uint256 => Pot) s_pot;
    mapping(uint256 => Roll) s_roll;
    mapping(bytes32 => uint256) vrfRequest;
    mapping(address => uint256) irollBalance;
    mapping(address => mapping(uint256 => uint256)) nextRoll;


    /// @notice Contract Initialization
    /// @param _token IROLL erc-20 token
    /// @param _vrf Chainlink VRF address
    /// @param _link Chainlink Token address
    /// @param _linkFee Chainlink VRF fee
    /// @param _priceFeed Chainlink Aggregator Interface address
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

    /// @notice Main contract funtion for paying entry for five 6-sided dice roll
    /// @dev Validates the entry and Pot status and then makes Chainlink VRF Request
    /// @dev rollResponse method handles Chainlink VRF response 
    /// @param _puid Pot Unique Identifier
    /// @return bytes32 of the Chainlink VRF Request Id
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

    /// @notice Handles the response from Chainlink VRF Requests 
    /// @dev Validates the response from Chainlink and match vrf requestId to roll caller
    /// @dev Call Dice library to convert and score random number to five 6-sided dice
    /// @dev Find the IROLL token amount reward player with based on dice combo and assign to player escrow
    /// @dev If Jackpot winner, calculate winnings based on pot settings and perform pot and network owners
    /// @dev Fire Event to record player Roll 
    /// @param _requestId Chainlink VRF RequestId 
    /// @param _random Chainklink VRF random number
    function rollResponse(bytes32 _requestId, uint256 _random) external {  
        require(msg.sender == address(VRF) && _requestId != 0 && _random > 0, "bad vrf");   
        uint256 rollId = vrfRequest[_requestId];
        require(rollId > 0, "bad current roll");               
        Roll storage r = s_roll[rollId];
        require(r.vrfId == _requestId && r.complete == false, "bad roll");
        Pot storage p = s_pot[r.PUID];  
        require(p.UID == r.PUID && p.active, "bad pot");

        //Dice Library call to get five 6-sided dice, is jackpot and combo reward index
        (bytes5 dice, bool isJackpot, uint8 rewardIndex) = Dice.score(_random, p.dice);

        //Get the tokens won add to player escrow account
        uint reward = (rewards[rewardIndex] * p.multiplier);        
        irollBalance[r.player] = (irollBalance[r.player] + reward);
        
        uint256 payout; 
        //Is Jackpot Winner 
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

        emit RollCompleted(r.player, r.vrfId, r.PUID, r.UID, r.jackpot, r.eth, r.iroll, r.dice, rewardIndex);
    }

    /// @dev Look at stored last roll for pot and see if enough time has elapsed between rolls
    /// @param _puid Pot Unique Id the player is rolling for
    /// @return bool has enough time elapsed between player rolls
    function allowed(uint256 _puid) public view returns(bool){
        return ((nextRoll[msg.sender][_puid] == 0) || (block.timestamp >= nextRoll[msg.sender][_puid]));     
    }

    /// @dev Transfer escrow balance to msg.sender
    function withdrawTokens() public {
        uint256 bal = irollBalance[msg.sender];
        if(bal > 0){
            IROLL.transfer(msg.sender, bal);
            irollBalance[msg.sender] = 0;
        }
    }

    /// @notice Accepts fund to increase balance of Pot
    /// @param _puid Pot Unique Id 
    /// @return uint256 of the Pot Balance after seed
    function seedPot(uint256 _puid) public payable returns(uint256) { 
        s_pot[_puid].balance = (s_pot[_puid].balance + msg.value);
        return s_pot[_puid].balance;
    } 

    /// @notice Return contract IROLL token balance
    function getTokenBalance() public view returns(uint256){
        return IROLL.balanceOf(address(this));
    }

    /// @notice Return Pot array length
    function getPotCount() public view returns(uint256){
        return pots.length;
    }

    /// @notice Return token rewards based on Pot settings
    /// @param _puid Pot Unique Id 
    /// @return uint256[11] array of the converted values for each reward index
    function getPotRewards(uint256 _puid) public view returns(uint256[11] memory){
        Pot storage p = s_pot[_puid];
        require(p.active, "bad pot");        
        if(p.multiplier > 1){
            uint8 m = p.multiplier;
            return [rewards[0]*m, rewards[1]*m, rewards[2]*m, rewards[3]*m, rewards[4]*m, rewards[5]*m, rewards[6]*m, rewards[7]*m, rewards[8]*m, rewards[9]*m, rewards[10]*m];
        }
        return rewards;
    }      

    /// @notice Get the Pot by Unique Id
    /// @param _puid Pot Unique Id
    /// @return Pot from struct array storage
    function getPot(uint256 _puid) public view returns(Pot memory){
        return s_pot[_puid];
    } 

    /// @notice Return Pot struct array
    /// @return uint256[] array of stored Pots
    function getPots() public view returns(uint256[] memory){ 
        return pots;
    } 

    /// @notice Return Pot current ETH balance
    /// @param _puid Pot Unique Id
    /// @return uint256 of ETH balance
    function getPotBalance(uint256 _puid) public view returns(uint256){
        return s_pot[_puid].balance;
    }     

    /// @notice Get Total Roll Count
    /// @return uint256 of Rolls struct array length
    function getRollCount() public view returns(uint256){
        return rolls.length;
    } 

    /// @notice Return Roll record by Roll Unique Id
    /// @param _ruid Roll Unique Id
    /// @return Roll struct
    function getRoll(uint256 _ruid) public view returns(Roll memory){
        return s_roll[_ruid];
    }

    /// @notice Return array of Rolls for Pot from Event Log
    /// @dev limits results to 200
    /// @param _puid Pot Unique Id
    /// @return Roll struct array
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

    /// @notice Return array of player Roll history from Event Log
    /// @param _player Address of the Player to look up
    /// @return Roll stuct array
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

    /// @notice Return msg.sender IROLL balance
    /// @return uint256 of token blance
    function getPlayerTokenBalance() public view returns(uint256){
        return IROLL.balanceOf(msg.sender);
    } 

    /// @notice Return msg.sender ETH escrow balance via PullPayment 
    /// @dev wrapper for PullPayment payments(address) method
    /// @return uint256 of escrow balance
    function getPlayerEthBalance() public view returns(uint256){
        return payments(msg.sender);
    }

    /// @notice Return amount of time before player is allowed to roll again
    /// @param _puid Pot Unique Id
    /// @return uint256 value of msg.sender last roll
    /// @return uint256 block timestamp for reference
    function getPlayerNextRoll(uint256 _puid) public view returns(uint256, uint256){
        return (nextRoll[msg.sender][_puid], block.timestamp);
    } 

    /// @notice Return reference rewards array values for winning combos
    /// @return uint256[11] array stored for reference
    function getRewards() public view returns(uint256[11] memory){
        return rewards;
    }  

    /// @notice Deposit LINK token for Pot Balance
    /// @param _puid Pot Unique Id
    /// @param _amount LINK to be transferred 
    /// @return uint256 LINK balance for Pot after deposit
    function depositPotLink(uint256 _puid, uint256 _amount) external returns(uint256){
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        require(LINK.transferFrom(msg.sender, address(this), _amount), "bad transfer");
        p.linkBalance = (p.linkBalance + _amount);
        return p.linkBalance;
    }   

    /// @notice Use Pot wallet to approve LINK
    /// @param _puid Pot Unique Id
    function approvePotLink(uint256 _puid, uint256 _amount) public {
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        LINK.approve(p.linkWallet, _amount);
    } 

    /// @notice Return active Pot LINK balance
    /// @param _puid Pot Unique Id
    /// @return uint256 Pot LINK balance
    function getPotLinkBalance(uint256 _puid) public view returns(uint256) {
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        return p.linkBalance;
    }

    /// @notice Update the Pot IROLL multiplier 
    /// @param _puid Pot Unique Id
    /// @param _multiplier Set the Pot multiplier 
    /// @return uint256 Pot multiplier 
    function setPotMultiplier(uint256 _puid, uint8 _multiplier) public onlyOwner returns(uint256) {
        Pot storage p = s_pot[_puid];
        require(p.active,"pot inactive");
        p.multiplier = _multiplier;
        return p.multiplier;
    }    

    /// @notice Update Pot LINK wallet address
    /// @param _puid Pot Unique Id
    /// @param _linkWallet LINK wallet address
    function setPotLinkWallet(uint256 _puid, address _linkWallet) public {
        Pot storage p = s_pot[_puid];
        require(p.active && (msg.sender == p.owner || msg.sender == owner()), "bad request");
        p.linkWallet = _linkWallet;
    }    

    /// @notice Only Owner Pot Owner address update - Only Owner
    /// @param _puid Pot Unique Id
    /// @param _owner Address of the new owner of Pot
    function setPotOwner(uint256 _puid, address _owner) public onlyOwner{
        require(!lock,"lock");
        lock = true;
        s_pot[_puid].owner = _owner; 
        lock = false;
    } 

    /// @notice Update VRF Fee amount - Only Owner
    /// @param _linkFee Amount of the LINK per request
    function setLinkFee(uint256 _linkFee) public onlyOwner{
        require(_linkFee > 0, "bad fee");
        linkFee = _linkFee;
    } 

    /// @notice Update the ETH amount for new Pot
    /// @param _price Fee to add new Pot
    function setPotPrice(uint256 _price) public onlyOwner{
        require(_price > 0, "bad price");
        potPrice = _price;
    }

    /// @notice Close Pot - Only Owner
    /// @dev Outstanding balances are returned to Owner
    /// @param _puid Pot Unique Id
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

    /// @notice Buy Pot 
    /// @param _ent Entry Fee
    /// @param _intr Interval between rolls
    /// @param _seed Percent of balance left for next player
    /// @param _fee 
    /// @param _dice Five 6-sided dice in bytes5 format
    /// @param _linkWallet LINK wallet for VRF payments
    /// @return uint256 Pot Unique Id
    function buyPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bytes5 _dice, address _linkWallet) public payable returns(uint256){
        require(msg.value == potPrice,"bad price");
        return addPot(_ent, _intrv, _seed, _fee, _dice, _linkWallet, 1);
    }

    /// @notice Add Pot to struct array - Only Owner
    /// @param _ent Entry Fee
    /// @param _intr Interval between rolls
    /// @param _seed Percent of balance left for next player
    /// @param _fee 
    /// @param _dice Five 6-sided dice in bytes5 format
    /// @param _linkWallet LINK wallet for VRF payments
    /// @param _multiplier Amount to increase IROLL rewards for combos
    function createPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bytes5 _dice, address _linkWallet, uint8 _multiplier) public onlyOwner returns(uint256) { 
       return addPot(_ent, _intrv, _seed, _fee, _dice, _linkWallet, _multiplier);
    } 

    /// @notice Add Pot to struct array
    /// @param _ent Entry Fee
    /// @param _intr Interval between rolls
    /// @param _seed Percent of balance left for next player
    /// @param _fee 
    /// @param _dice Five 6-sided dice in bytes5 format
    /// @param _linkWallet LINK wallet for VRF payments
    /// @param _multiplier Amount to increase IROLL rewards for combos
    /// @return uint256 Pot Unique Id
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

    /// @notice Return current ETH price 
    /// @return Latest Round Data from Chainlink Price Feed
    function getCurrentEthPrice() public view returns (int) {
        (,int price,,,) = PRICEFEED.latestRoundData();
        return price;
    }    
}