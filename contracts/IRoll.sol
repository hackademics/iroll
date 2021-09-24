// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import { Dice } from './library/Dice.sol';
import "./IRollRNG.sol";
import "./interface/IIRoll.sol";
import "./interface/IIRollToken.sol";

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/utils/introspection/ERC1820Implementer.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract IRoll is IIRoll, Ownable, PullPayment, ReentrancyGuard, Pausable, IERC777Recipient, ERC1820Implementer {
    
    using SafeMath for *;
	using Address  for address;    
    using Counters for Counters.Counter;
    using Dice for uint8[5];
    using Dice for uint256; 

    /// IROLL token
    IERC777 public token;

    IRollRNG private rng;

    /// pot unique ids
    Counters.Counter public PUID;

    /// store thee rollers
    address payable[] private players;

    /// player's VRF Request in flight for pot
    mapping(address => mapping(uint256 => bytes32)) plyrVrf;  

    /// player's VRF Request in flight for pot
    mapping(address => mapping(uint256 => uint8[5])) plyrPicks;           

    /// player's time interval to wait between rolls
    mapping(address => mapping(uint256 => uint256)) nextRoll;     

    uint256[] private pots;
    mapping(uint256 => Pot) mPot; 
    
    /// IERC777 token recipient
    IERC1820Registry internal constant erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant RECIPIENT_HASH = keccak256("ERC777TokensRecipient");   

    constructor(address _token) {         
        token = IERC777(_token);

        /// ERC1820 RECIPIENT / SENDER
        erc1820.setInterfaceImplementer(address(this), RECIPIENT_HASH, address(this));   
    }

    /// @dev Roll function
    /// loads pot by id, if pot inactive or 404 then revert
    function roll(uint256 _puid, uint8[5] calldata _pi) public payable override whenNotPaused returns(bytes32){
        Pot storage p = mPot[_puid];
        require(p.UID == _puid && p.active, "404");     
        require(allowed(p.UID), "wait");
        require(p.entry == msg.value, "fee");
        require(p.balance > p.entry, "seed");

        if(p.picks && _pi.validDice() == false){ revert("picks"); }

        plyrPicks[msg.sender][_puid] = _pi;

        p.balance = p.balance.add(msg.value);        

        nextRoll[msg.sender][p.UID] = block.timestamp.add(p.interval);
        
        /// request random number from VRF
        /// todo REMOVE chain id check before mainnet
        plyrVrf[msg.sender][p.UID] = new IRollRNG(0x01BE23585060835E02B77ef475b0Cc51aA1e0709, 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B).mockRequest(p.UID, msg.sender);
        //plyrVrf[msg.sender][p.UID] = new IRollRNG(vrfToken, vrfCoord).request(p.UID);       

        return (0);
    } 

    /// @dev check if roll request satisfies pot interval; 
    function allowed(uint256 _puid) public override view returns(bool){
        if(nextRoll[msg.sender][_puid] == 0){ return true;}
        if(block.timestamp >= nextRoll[msg.sender][_puid]){ return true; }        
        return false;
    }    

    /// @dev handle call back 
    function vrfCallback(bytes32 _vrfId, uint256 _vrfNum, uint256 _puid, address _player) external {
        //require(plyrVrf[_player][p.UID] == _vrfID, "404");
        
        Pot storage pot = mPot[_puid];
        require(pot.UID == _puid && pot.active, "404");

        uint8[5] memory dice = _vrfNum.getDice();
        uint8[5] memory picks = plyrPicks[_player][_puid];

        bool jackpot = false;
        uint256 tokens = 0;
        uint256 payout = 0;
        
        /// score 
        (jackpot, tokens) = Dice.score(pot.sixes, pot.picks, pot.custom, pot.rewards, pot.customRoll, dice, picks);

        /// pay winners
        if(jackpot){           
            //calculate payout (balance - seedPercent - feePercent)
            uint256 pSeed = pot.balance.mul(pot.seed).div(100);
            uint256 pFee = pot.balance.sub(pSeed).mul(pot.fee).div(100);
            payout =  pot.balance.sub(pSeed).sub(pFee);

            /// pay player
            _asyncTransfer(_player, payout);

            /// pay pot owner
            _asyncTransfer(pot.owner, pFee);

            /// update pot balance
            pot.balance = pSeed;

            emit Jackpot(_player, _vrfId, _puid, dice, picks, payout, tokens);
        }

        /// reward tokens
        if(tokens > 0) {
            if(token.balanceOf(address(this)) > tokens){
                token.send(payable(_player), tokens, abi.encodePacked(_puid)); 
            }
        }         

        emit Rolls(_player,_vrfId, pot.UID, jackpot, payout, tokens, dice, picks);       
    } 
    
    /// @dev create a new pot 
    function createPot(uint256 _ent, uint256 _intrv, uint8 _seed, uint8 _fee, bool _sxs, bool _pck, bool _cstm, uint8[5] calldata _crll, uint256[11] calldata _rwd) 
    public override returns(uint256) { 
        PUID.increment(); 

        Pot storage p = mPot[PUID.current()];        
        p.UID = PUID.current();       
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

        pots.push(p.UID);

        return p.UID;
    }         

    /// @dev accepts ether to increase pot
    function seedPot(uint256 _puid) public payable override whenNotPaused { 
        require(mPot[_puid].UID > 0, "404");
        mPot[_puid].balance = mPot[_puid].balance.add(msg.value);
    } 

    /// @dev get pot from pot array, revert if not found or not active
    function getPot(uint256 _puid) public override view whenNotPaused returns(Pot memory){
        require(mPot[_puid].UID > 0 && mPot[_puid].active, "404");
        return mPot[_puid];
    } 

    /// @dev get pots
    function getPots() public override view whenNotPaused returns(uint256[] memory){ 
        return pots;
    }   

    /// @dev get player token balance
    function getPlayerBalance() public override view whenNotPaused returns(uint256){
        return token.balanceOf(msg.sender);
    } 

    /// @dev get player token balance
    function getRewardBalance() public override view whenNotPaused returns(uint256){
        return token.balanceOf(address(this)); 
    }     

    /// @dev update the pot's owner
    function setPotOwner(uint256 _puid, address _owner) public override onlyOwner whenNotPaused {
        mPot[_puid].owner = _owner; 
    } 

    function setPotActive(uint _puid, bool _actv) public override onlyOwner whenNotPaused {
        mPot[_puid].active = _actv; 
    }       

    /// @dev required for ERC777 token recipient
    function tokensReceived( address _op, address _frm, address _to, uint256 _amt, bytes calldata _usrd, bytes calldata _opd) external override {
        require(msg.sender == address(token));
        emit TokensReceived(msg.sender, _op, _frm, _to, _amt, _usrd, _opd);
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
    //function testScore(uint256 _id, uint8[5] calldata _di, uint8[5] calldata _pi) public onlyOwner returns(bool, uint256) {
        //plyrVrf[msg.sender][_id] = 0;
        //return Dice.score(msg.sender, _id, _di, _pi);
    //}

}