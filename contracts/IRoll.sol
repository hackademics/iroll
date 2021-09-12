// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import { Dice } from './library/Dice.sol';
import "./IRollRNG.sol";
import "./interface/IIRoll.sol";
import "./interface/IIRollToken.sol";

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/utils/introspection/ERC1820Implementer.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract IRoll is IIRoll, Ownable, PullPayment, ReentrancyGuard, Pausable, IERC777Recipient, IERC777Sender, ERC1820Implementer {
    using SafeMath for *;
	using Address  for address;    
    using Counters for Counters.Counter;
    using Dice for uint8[5];
    using Dice for uint256; 

    /// IROLL token
    IERC777 public token;

    /// LINK VRF Coordinator
    address public linkVRFCoordinator;

    /// LINK token
    address public linkVRFToken;

    /// pot unique ids
    Counters.Counter public PUID;

    /// roll unique ids
    Counters.Counter public RUID;   

    /// store thee rollers
    address payable[] private players; 

    /// store pot balances
    mapping(uint256 => uint256) pBal;

    /// store pot owners
    mapping(uint256 => address) pOwnr; 

    /// store pot custom roll
    mapping(uint256 => uint8[5]) pCRoll;   

    /// player's VRF Request in flight for pot
    mapping(address => mapping(uint256 => bytes32)) plyrVrf;            

    /// player's time interval to wait between rolls
    mapping(address => mapping(uint256 => uint256)) nextRoll;     

    Pot[] pots; 
    mapping(uint256 => Pot) mPot; 
    
    Roll[] rolls; 
    mapping(uint256 => Roll) mRoll;

    /// IERC777 token sender and recipient set up
    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 constant private TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");    

    constructor(address _token, address _linkToken, address _linkCoordinator) { 
        
        /// IRoll token address
        token = IERC777(_token);

        /// VRF Link token
        linkVRFToken = _linkToken;

        /// VRF coordinator 
        linkVRFCoordinator = _linkCoordinator;

        /// ERC1820
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
        
    }

    /// @dev Roll function
    /// loads pot by id, if pot inactive or 404 then revert
    /// check roll interval for pot to see if player can roll again
    /// entry fee must match msg.value and pot balance must be twice the entry fee
    /// if Player Picks enabled then validate picks are valid dice
    function roll(uint256 _puid, uint8[5] calldata _pi) public payable override whenNotPaused returns(bytes32){
        /// will revert if pot doesn't exist or is not active
        Pot memory p = getPot(_puid);
        
        /// check if roll is within pot interal duration        
        require(allowed(p.UID));

        /// check if player entry fee matches pot entry fee
        require(p.entry == msg.value, "fee");

        /// check pot balance to ensure prize
        require(pBal[p.UID] > p.entry.mul(2), "seed");

        /// check picks if player pick enabled
        if(p.picks == 1 && _pi.validDice() == false){ revert("picks"); }

        /// add entry fee to pot balance
        pBal[p.UID] = pBal[p.UID].add(msg.value);

        /// save player
        players.push(payable(msg.sender)); 

        /// new incremental unique id for player roll
        RUID.increment();      

        /// init roll struct
        Roll memory r = mRoll[RUID.current()];
        r.UID = RUID.current();
        r.PUID = p.UID; 
        r.player = payable(msg.sender);
        r.picks = _pi;
        r.created = uint32(block.timestamp); 

        /// add roll
        rolls.push(r);

        //set players next roll interval
        nextRoll[msg.sender][p.UID] = p.interval;

        /// request random number from VRF
        r.vrfId = new IRollRNG(linkVRFToken, linkVRFCoordinator).mockRequest(p.UID, r.UID);

        emit RollInit(msg.sender, p.UID, r.vrfId, pBal[p.UID], address(this).balance);

        return (r.vrfId);
    } 

    /// @dev check if roll request satisfies pot interval; 
    function allowed(uint256 _puid) public override view returns(bool){
        if(nextRoll[msg.sender][_puid] == 0){ return true;}
        if(block.timestamp <= nextRoll[msg.sender][_puid]){ return true; }
        revert("wait");
    }

    /// @dev handle call back 
    function vrfCallback(bytes32 _reqId, uint256 _rnd, uint256 _puid, uint256 _ruid) external whenNotPaused {
       
        emit VRF(msg.sender, _reqId, _puid, _ruid);
        
        //plyrPot[msg.sender] = _puid;
        plyrVrf[msg.sender][_puid] = _reqId;
 
        /// get roll 
        Roll memory r = getRoll(_ruid);   
        r.vrfId = _reqId;
        r.vrfNum = _rnd;
        
        /// convert random to dice
        r.dice = _rnd.getDice();
        
        /// score roll
        (r.jackpot, r.tokens) = score(r.PUID, r.UID, r.dice, r.picks);

        /// pay jackpot winners
        if(r.jackpot) (r.payout, r.seed, r.fee) = pay(r.PUID);

        /// transfer reward tokens
        if(r.tokens > 0) reward(r.PUID, r.tokens); 
        
        /// save roll
        rolls.push(r);

        emit Finished(msg.sender, r.UID, r.PUID, r.vrfId,r.jackpot, r.payout, r.seed, r.fee, r.dice, r.picks);         
    }

    /// @dev Pay Jackpot winners and pot owner winnings
    function pay(uint256 _puid) internal nonReentrant whenNotPaused returns(uint256, uint256, uint256){
        Pot memory p = getPot(_puid);
        //calculate payout (balance - seedPercent - feePercent)
        uint256 balance = pBal[p.UID];
        uint256 paySeed = balance.mul(p.seed).div(100);
        uint256 payFee = balance.sub(paySeed).mul(p.fee).div(100);
        uint256 payout = balance.sub(paySeed).sub(payFee);

        /// pay player
        _asyncTransfer(msg.sender, payout);

        /// pay pot owner
        _asyncTransfer(pOwnr[p.UID], payFee);

        /// set pot balance to seed
        pBal[p.UID] = paySeed;

        /// check if pot requires seeding
        if(pBal[p.UID] <= p.entry.mul(2)){
            emit SeedAlert(msg.sender, p.UID, pBal[p.UID], address(this).balance);
        }
        
        emit Paid(msg.sender, pOwnr[p.UID], plyrVrf[msg.sender][p.UID], p.UID, payout, paySeed, payFee, pBal[p.UID], address(this).balance);

        return (payout, paySeed, payFee);
    }  

    /// @dev Transfer reward tokens to player and pot owner
    function reward(uint256 _puid, uint256 _tokens) internal nonReentrant whenNotPaused{
        Pot memory p = getPot(_puid);        
        token.send(payable(msg.sender), _tokens, "0x");
        
        emit Reward(msg.sender, p.UID, plyrVrf[msg.sender][p.UID], pOwnr[p.UID], address(token), p.wallet, _tokens);
    }

    function testReward() public returns(uint256){
        Pot memory p = getPot(1);
        token.send(payable(msg.sender), 1, "0x");
        return token.balanceOf(address(this));
    }             

    /// @dev score the dice roll and determine reward amount based on combo 
    /// todo move to a library file to reduce contract size  
    function score(uint256 _puid, uint256 _ruid, uint8[5] memory _di, uint8[5] memory _pi) internal nonReentrant whenNotPaused returns(bool, uint256){
        require(_di.validDice(), "_di");
        
        bool won = false;
        uint256 rwd = 0;

        //Roll memory r = getRoll(_ruid);
        Pot memory p = getPot(_puid);

        if(p.sixes == 1 && _di.isAllSixes()){
            won = true;
            rwd = p.rewards[1];
        } else if(p.sixes == 0 && _di.isFiveOfKind()){
            won = true;
            rwd = p.rewards[0];
        }else if(p.picks == 1 && _di.isMatch(_pi)){
            won = true;
            rwd = p.rewards[2];
        } else if(p.custom == 1 && _di.isMatch(pCRoll[p.UID])){
            won = true;
            rwd = p.rewards[3];
        }  

        /// @dev exit early if jackpot to skip additional scoring
        if(won){
            emit Combo(msg.sender, _puid, _ruid, 0, _di, _pi, rwd);
            return (won, rwd);
        }   

        /// @dev get token rewards index for non jackpot combinations
         if(_di.isFourOfKind()){ rwd = p.rewards[4]; } 
         else if(_di.isLargeStraight()){ rwd = p.rewards[5]; } 
         else if(_di.isFullHouse()){ rwd = p.rewards[6]; }
         else if(_di.isSmallStraight()){ rwd = p.rewards[7]; } 
         else if(_di.isThreeOfAKind()){ rwd = p.rewards[8]; } 
         else if(_di.isTwoPair()){ rwd = p.rewards[9]; } 
         else if(_di.isSinglePair()){ rwd = p.rewards[10]; }

        /// if reward is gt 0 then emit combo event
         if(rwd > 0){ emit Combo(msg.sender, _puid, _ruid, 0, _di, _pi, rwd); }

         return (false, rwd);
    }      

    /// @dev create a new pot 
    function createPot(address _wallet, uint256 _entry, uint256 _intrv, uint8 _seed, uint8 _fee, uint8 _sxs, uint8 _pck, uint8 _cstm, uint8[5] calldata _crll, uint256[11] calldata _rwd) public onlyOwner nonReentrant returns(uint256) {
        
        /// new incremental uinque id for pot
        PUID.increment();

        Pot memory p = mPot[PUID.current()];
            p.UID = PUID.current();       
            p.wallet = _wallet;
            p.entry = _entry;
            p.interval = uint256(_intrv * 1 minutes);
            p.seed = _seed;
            p.fee = _fee;
            p.sixes = _sxs;
            p.picks = _pck;
            p.custom = _cstm;
            p.rewards = _rwd;

        pCRoll[PUID.current()] = _crll;
        pOwnr[PUID.current()] = owner();

        pots.push(p);

        emit PotInit(msg.sender, p.UID, p.wallet, p.entry,  p.interval,  p.seed,  p.fee);

        return p.UID;
    } 

    /// Pull Payment escrow balance for player's winnings
    function getPayments() public view returns(uint256){
        require(isPlayer(msg.sender), "notplayer");
        return payments(msg.sender); 
    } 

    /// @dev Pull Payment player withdaws their current balance
    function withdraw(address payable _player) public nonReentrant whenNotPaused { 
        require(isPlayer(msg.sender), "notplayer");
        withdrawPayments(_player); 
    }   

    /// @dev check address to make sure it's been logged as a player
    function isPlayer(address _player) public view returns(bool){
        for(uint i=0;i<players.length;i++){
            if(players[i] == _player){ return true; }
        }
        revert("404");
    }          

    /// @dev accepts ether to increase pot
    function seedPot(uint256 _puid) public payable override nonReentrant { 
        pBal[_puid] = pBal[_puid].add(msg.value);
        emit Seeded(msg.sender, _puid, msg.value, address(this).balance, pBal[_puid]);
    } 

    /// @dev get pot from pot array, revert if not found or not active
    function getPot(uint256 _puid) public view returns(Pot memory){
        for(uint i=0; i < pots.length; i++){
            if(pots[i].UID == _puid) return pots[i];
        }
        revert("404");
    }       

    /// @dev get list of pot structs
    function getPots() public view returns(Pot[] memory){ return pots; } 

    /// @dev get current pot balance
    function getPotBalance(uint256 _puid) public view returns(uint256){
        require(_puid > 0, "puid");
        return pBal[_puid];
    }   

    /// @dev get roll by UID
    function getRoll(uint256 _ruid) public view returns (Roll memory){
        require(_ruid > 0 && rolls.length > 0, "rolls");
        for(uint i=0; i < rolls.length; i++){
            if(rolls[i].UID == _ruid) return rolls[i];
        }
        revert("404");  
    } 

    /// @dev get all rolls
    function getRolls() public view returns (Roll[] memory){ return rolls; }   

    /// @dev get all rolls for pot
    function getPotRolls(uint256 _puid) public view returns (Roll[] memory){     
        Roll[] memory pr;
        for(uint i=0;i<rolls.length;i++){
            if(rolls[i].PUID == _puid) pr[i] = (rolls[i]);
        }
        return pr;       
    }

    /// @dev update the pot's owner
    function setPotOwner(uint256 _puid, address _owner) public onlyOwner whenNotPaused {
        require(_puid > 0 && _owner != address(0), "idownr");
        emit OwnerSet(msg.sender, pOwnr[_puid], _owner, _puid);
        pOwnr[_puid] = _owner;
    }   

    /// @dev pause contract from executing
    function pause() public whenNotPaused onlyOwner {
        emit PauseSet(msg.sender);
        _pause();        
    }

    /// @dev unpause contract and resume executing
    function unpause() public whenPaused onlyOwner {
        emit UnPauseSet(msg.sender);
        _unpause();        
    }   

    /// @dev required for ERC777 token recipient
    function tokensReceived( address _op, address _frm, address _to, uint256 _amt, bytes calldata _usrdata, bytes calldata _opdata) external override {
        require(msg.sender == address(token));
        emit TokensReceived(msg.sender, _op, _frm, _to, _amt, _usrdata, _opdata);
    }      

    /// @dev required for ERC777 token sender
    function tokensToSend(address _op, address _frm, address _to, uint256 _amt, bytes calldata _usrdata, bytes calldata _opdata) external override {
        emit TokensSent(msg.sender, _op, _frm, _to, _amt, _usrdata, _opdata);
    }  

    /// @dev TEST - remove before mainnet
    function testScore(uint256 _id, uint8[5] calldata _di, uint8[5] calldata _pi) public onlyOwner returns(bool, uint256) {
        //plyrPick[msg.sender][_id] = _pi;
        plyrVrf[msg.sender][_id] = 0;
        return score(_id, 1, _di, _pi);
    }

    /// @dev TEST - remove before mainnet
    function testPay(uint256 _id) public onlyOwner returns(uint256, uint256, uint256) {
        players.push(payable(msg.sender));
        plyrVrf[msg.sender][_id] = 0;
        return pay(1);
    }            


}