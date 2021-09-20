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
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
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
    address public vrfCoord;

    /// LINK token
    address public vrfToken;

    /// pot unique ids
    Counters.Counter public PUID;

    /// pot unique ids
    Counters.Counter public RUID;    

    /// store thee rollers
    address payable[] private players;

    mapping(address => uint256) plyrTokensWon;

    /// player's VRF Request in flight for pot
    mapping(address => mapping(uint256 => bytes32)) plyrVrf;         

    /// player's time interval to wait between rolls
    mapping(address => mapping(uint256 => uint256)) nextRoll;     

    /// store Pots
    Pot[] pots;
    mapping(uint256 => Pot) mPot; 
    
    /// store Rolls 
    Roll[] rolls; 
    mapping(uint256 => Roll) mRoll;
    mapping(address => uint256[]) plyrRolls;

    /// IERC777 token sender and recipient set up
    IERC1820Registry internal constant erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant RECIPIENT_HASH = keccak256("ERC777TokensRecipient");
    bytes32 private constant SENDER_HASH = keccak256("ERC777TokensSender");    

    constructor(address _token, address _vrfToken, address _vrfCoord) {         
        /// IRoll token address
        token = IERC777(_token);

        /// VRF Link token
        vrfToken = _vrfToken;

        /// VRF coordinator 
        vrfCoord = _vrfCoord;

        /// ERC1820 RECIPIENT
        erc1820.setInterfaceImplementer(address(this), RECIPIENT_HASH, address(this));    
        erc1820.setInterfaceImplementer(address(this), SENDER_HASH, address(this));    
    }

    /// @dev Roll function
    /// loads pot by id, if pot inactive or 404 then revert
    function roll(uint256 _puid, uint8[5] calldata _pi) public payable override whenNotPaused returns(bytes32){
        Pot storage p = mPot[_puid];
        require(p.UID == _puid && p.active, "idactive");
        
        /// check if roll is within pot interal duration        
        require(allowed(p.UID));

        /// check if player entry fee matches pot entry fee
        require(p.entry == msg.value, "fee");

        /// check pot balance to ensure prize
        require(p.balance > p.entry, "seed");

        /// check picks if player pick enabled
        if(p.picks && _pi.validDice() == false){ revert("picks"); }

        /// add entry fee to pot balance
        p.balance = p.balance.add(msg.value);

        /// store player address
        players.push(payable(msg.sender));               

        /// set interval for next roll
        nextRoll[msg.sender][p.UID] = block.timestamp.add(p.interval);

        RUID.increment();
        Roll storage r = mRoll[RUID.current()];
        r.UID = RUID.current(); 
        r.PUID = p.UID;
        r.player = msg.sender;
        r.picks = _pi;        

        /// request random number from VRF
        /// todo REMOVE chain id check before mainnet
        plyrVrf[msg.sender][p.UID] = new IRollRNG(vrfToken, vrfCoord).mockRequest(p.UID, r.UID);
        //plyrVrf[msg.sender][p.UID] = new IRollRNG(vrfToken, vrfCoord).request(p.UID);       

        emit RollInit(msg.sender, plyrVrf[msg.sender][p.UID], p.UID, r.picks, p.balance, address(this).balance); 

        return (0);
    } 

    /// @dev check if roll request satisfies pot interval; 
    function allowed(uint256 _puid) public override view returns(bool){
        if(nextRoll[msg.sender][_puid] == 0){ return true;}
        if(block.timestamp >= nextRoll[msg.sender][_puid]){ return true; }        
        revert("wait");
    }    

    /// @dev handle call back 
    function vrfCallback(bytes32 _reqId, uint256 _rnd, uint256 _puid, uint256 _ruid) external {
        emit VRF(msg.sender, _reqId, _puid, _ruid); 
       
        Pot storage pot = mPot[_puid];
        require(pot.UID == _puid && pot.active, "idact");
 
        Roll storage r = mRoll[_ruid];
        require(r.PUID == pot.UID, "pot");

        r.dice = _rnd.getDice();
        r.vrfNum = _rnd;
        r.vrfId = _reqId;

        // /// score 
        (r.jackpot, r.tokens) = score(pot.UID, r.dice, r.picks);

        /// pay jackpot winners
        if(r.jackpot) (r.payout, r.seed, r.fee) = pay(pot.UID, r.UID, r.player);

        // /// reward tokens
        if(r.tokens > 0) reward(r.player, pot.UID, r.UID, r.tokens);  
        
        rolls.push(r);   

        plyrRolls[r.player].push(r.UID);     

        emit Fin(r.player, r.vrfId, r.UID, r.PUID, r.jackpot, r.payout, r.tokens, r.dice, r.picks);       
    } 

    /// @dev Pay Jackpot winners and pot owner winnings
    function pay(uint256 _puid, uint256 _ruid, address _payee) internal nonReentrant whenNotPaused returns(uint256, uint256, uint256){
        Pot storage p = mPot[_puid];
        
        //calculate payout (balance - seedPercent - feePercent)
        uint256 pSeed = p.balance.mul(p.seed).div(100);
        uint256 pFee = p.balance.sub(pSeed).mul(p.fee).div(100);
        uint256 pPay =  p.balance.sub(pSeed).sub(pFee);

        /// pay player
        _asyncTransfer(_payee, pPay);

        /// pay pot owner
        _asyncTransfer(p.owner, pFee);

        p.balance = pSeed;

        /// check if balance is twice entry fee
        if(p.balance <= p.entry.mul(2)){ emit SeedAlert(msg.sender, p.UID,p.balance, address(this).balance); }
        
        emit Paid(msg.sender, _payee, p.owner, p.UID, _ruid, pPay, pSeed, pFee, p.balance, address(this).balance);  

        return (pPay, pSeed, pFee);
    } 

    /// @dev Transfer reward tokens to player and pot owner
    function reward(address _payee, uint256 _puid, uint256 _ruid, uint256 _amt) internal nonReentrant whenNotPaused{  
        Pot storage p = mPot[_puid];
        if(token.balanceOf(address(this)) > _amt){
            plyrTokensWon[_payee] = plyrTokensWon[_payee].add(_amt);
            //token.send(payable(msg.sender), _amt, abi.encodePacked(_puid, _ruid));        
            emit Reward(msg.sender, plyrVrf[_payee][p.UID], p.UID, _ruid, address(token), address(this), _amt);   
        }
    }   
    
    /// @dev score the dice roll and determine reward amount based on combo 
    /// todo move to a library file to reduce contract size  
    function score(uint256 _puid, uint8[5] memory _di, uint8[5] memory _pi) internal nonReentrant whenNotPaused returns(bool, uint256){
        require(_di.validDice(), "_di");
        
        Pot storage p = mPot[_puid];
        
        bool won = false;
        uint256 rwd = 0;        

        if(p.sixes && _di.isAllSixes()){
            won = true;
            rwd = p.rewards[1];
        } else if(!p.sixes && _di.isFiveOfKind()){
            won = true;
            rwd = p.rewards[0];
        }else if(p.picks && _pi.validDice() && _di.isMatch(_pi)){
            won = true;
            rwd = p.rewards[2];
        } else if(p.custom && p.customRoll.validDice() && _di.isMatch(p.customRoll)){
            won = true;
            rwd = p.rewards[3];
        }  

        /// @dev exit early if jackpot to skip additional scoring
        if(won){
            emit Jackpot(msg.sender, plyrVrf[msg.sender][p.UID], p.UID, _di, _pi, rwd); 
            return (won, rwd);
        }   

        // /// @dev get token rewards index for non jackpot combinations
         if(_di.isFourOfKind()){ rwd = p.rewards[4]; } 
        else if(_di.isLargeStraight()){ rwd = p.rewards[5]; }  
        else if(_di.isFullHouse()){ rwd = p.rewards[6]; }
        else if(_di.isSmallStraight()){ rwd = p.rewards[7]; } 
        else if(_di.isThreeOfAKind()){ rwd = p.rewards[8]; } 
        else if(_di.isTwoPair()){ rwd = p.rewards[9]; } 
        else if(_di.isSinglePair()){ rwd = p.rewards[10]; }

        // /// if reward is gt 0 then emit combo event
        if(rwd > 0){ emit Combo(msg.sender, plyrVrf[msg.sender][p.UID], p.UID, _di, _pi, rwd); }

         return (false, rwd);
    }   

    /// @dev create a new pot 
    function createPot(address _wlt, uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bool _sxs, bool _pck, bool _cstm, uint8[5] calldata _crll, uint256[11] calldata _rwd) 
    public override returns(uint256) {
        PUID.increment(); 

        Pot storage p = mPot[PUID.current()];        
        p.UID = PUID.current();       
        p.wallet = _wlt;
        p.entry = _ent;
        p.interval = uint256(_intrv * 1 minutes);
        p.seed = _seed;
        p.fee = _fee;
        p.sixes = _sxs;
        p.picks = _pck;
        p.custom = _cstm;
        p.rewards = _rwd;
        p.owner = owner();
        p.active = true;
        p.customRoll = _crll;
        p.balance = 0;

        pots.push(p);

        emit PotInit(msg.sender, p.UID, p.wallet, p.entry,  p.interval,  p.seed,  p.fee);

        return p.UID;
    }         

    /// @dev accepts ether to increase pot
    function seedPot(uint256 _puid) public payable override whenNotPaused { 
        require(mPot[_puid].UID > 0, "404");
        mPot[_puid].balance = mPot[_puid].balance.add(msg.value);
        emit Seeded(msg.sender, _puid, msg.value, address(this).balance, mPot[_puid].balance);
    } 

    /// @dev get pot from pot array, revert if not found or not active
    function getPot(uint256 _puid) public override view whenNotPaused returns(Pot memory){
        require(mPot[_puid].UID > 0 && mPot[_puid].active, "404");
        return mPot[_puid];
    } 

    /// @dev get pots
    function getPots() public override view whenNotPaused returns(Pot[] memory){
        return pots;
    }    

    /// @dev get current pot balance
    function getPotBalance(uint256 _puid) public override view whenNotPaused returns(uint256){
        require(mPot[_puid].UID > 0, "404");
        return mPot[_puid].balance;
    }   

    /// @dev get roll by UID
    function getRoll(uint256 _ruid) public override view whenNotPaused returns (Roll memory){
        require(mRoll[_ruid].PUID > 0, "404"); 
        return mRoll[_ruid]; 
    } 

    /// @dev get all rolls
    function getRolls() public override view whenNotPaused returns (uint256[] memory){ 
        return plyrRolls[msg.sender];    
    }  

    function getPlayerRollCount() public view returns(uint256){
        return plyrRolls[msg.sender].length;
    } 

    function getRollCount() public view returns(uint256){
        return rolls.length;
    }     

    /// @dev get all rolls for pot
    function getPotRolls(uint256 _puid) public override view whenNotPaused returns (Roll[] memory){     
        Roll[] memory pr;
        for(uint i=0;i<rolls.length;i++){
            if(rolls[i].PUID == _puid) pr[i] = (rolls[i]);
        }
        return pr;       
    }

    /// @dev update the pot's owner
    function setPotOwner(uint256 _puid, address _owner) public override onlyOwner whenNotPaused {
        emit OwnerSet(msg.sender, _puid, mPot[_puid].owner, _owner);
        mPot[_puid].owner = _owner; 
    } 

    function setPotActive(uint _puid, bool _actv) public override onlyOwner whenNotPaused {
         emit ActiveSet(msg.sender, _puid, mPot[_puid].active, _actv);
        mPot[_puid].active = _actv; 
    }  

    function setPotRoll(uint _puid, uint8[5] calldata _pcr) public override onlyOwner whenNotPaused {
        emit RollSet(msg.sender, _puid, mPot[_puid].customRoll, _pcr);
        mPot[_puid].customRoll = _pcr; 
    }    

    function setPotWallet(uint _puid, address _wlt) public override onlyOwner whenNotPaused {
        mPot[_puid].wallet = _wlt; 
    }       

    /// @dev required for ERC777 token recipient
    function tokensReceived( address _op, address _frm, address _to, uint256 _amt, bytes calldata _usrd, bytes calldata _opd) external override {
        require(msg.sender == address(token));
        emit TokensReceived(msg.sender, _op, _frm, _to, _amt, _usrd, _opd);
    }  

    /// @dev required for ERC777 token sender
    function tokensToSend(address _op, address _frm, address _to, uint256 _amt, bytes calldata _usrd, bytes calldata _opd) external override {
        emit TokensSent(msg.sender, _op, _frm, _to, _amt, _usrd, _opd);
    }  

    /// @dev register address as sender
    function senderFor(address _acct) public onlyOwner {
        _registerInterfaceForAddress(SENDER_HASH, _acct);
    }        

    /// @dev pause contract from executing
    function pause() public whenNotPaused onlyOwner {
        emit PauseSet(msg.sender, true);
        _pause();        
    }

    /// @dev unpause contract and resume executing
    function unpause() public whenPaused onlyOwner {
        emit PauseSet(msg.sender, false);
        _unpause();        
    } 

    /// @dev distribute tokens to players
    /// check not to drop more than half of tokens in contract
    /// balance/2 > amount x num of players
    function airdrop(uint256 _amt) public onlyOwner whenNotPaused {
        require(token.balanceOf(address(this)).div(2) > _amt.mul(players.length),"funds");
        for(uint256 i=0;i<players.length;i++){
            address r = players[i];
            token.send(r, _amt, "0x");
        }
    }    

    /// @dev TEST - remove before mainnet
    /// todo REMOVE
    function testScore(uint256 _id, uint8[5] calldata _di, uint8[5] calldata _pi) public onlyOwner returns(bool, uint256) {
        plyrVrf[msg.sender][_id] = 0;
        return score(_id, _di, _pi);
    }

    /// @dev TEST - remove before mainnet
    /// todo REMOVE
    function testPay(uint256 _id) public onlyOwner returns(uint256, uint256, uint256) {
        plyrVrf[msg.sender][_id] = 0;
        return pay(_id, 1, msg.sender);
    }            


}