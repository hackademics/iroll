// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IIRoll {

    struct Pot {
        address wallet;
        uint8 seed;
        uint8 fee;
        uint8 sixes;
        uint8 picks;
        uint8 custom;             
        uint256 entry;
        uint256 interval;
        uint256 UID; 
        uint256[11] rewards;           
    }

    /// @dev holds all the specifics of a single roll for player
    struct Roll {
        address payable player;
        bytes32 vrfId;
        bool jackpot;
        uint32 created;   
        uint8[5] dice;
        uint8[5] picks;    
        uint256 tokens;                                      
        uint256 vrfNum;
        uint256 payout;
        uint256 fee;
        uint256 seed;                  
        uint256 UID;
        uint256 PUID;      
    }

    /// @dev initiates a new roll for the player by requesting random number from Chainlink VRF
    function roll(uint256 _puid, uint8[5] calldata _pi) external payable returns(bytes32);

    /// @dev check if roll request satisfies pot interval; 
    function allowed(uint256 _puid) external view returns(bool);

    /// @dev Only Admin can seed pot
    function seedPot(uint256 _puid) external payable;         

    event PotInit(address indexed sender, uint256 indexed puid, address wallet, uint256 entry, uint256 interval, uint8 seed, uint8 fee);
    event Seeded(address indexed sender,uint256 indexed puid, uint256 amt, uint256 bal, uint256 potBalance);
    
    /// @dev events for the Roll lifecycle
    event RollInit(address indexed sender, uint256 indexed puid, bytes32 indexed vrfId, uint256 potBalance, uint256 houseBalance);
    event VRF(address indexed sender, bytes32 indexed vrfId, uint256 indexed puid, uint256 ruid);
    event Jackpot(address indexed sender, uint256 indexed ruid, bytes32 indexed vrfId, uint256 payout, uint256 seed, uint256 fee, uint8[5] dice, uint8[5] picks);
    event Paid(address indexed sender, address indexed owner, bytes32 indexed vrfId, uint256 puid, uint256 payout, uint256 seed, uint256 fee, uint256 potBalance, uint256 houseBalance);
    event SeedAlert(address indexed sender, uint256 indexed puid, uint256 potBalance, uint256 houseBalance);
    event Reward(address indexed sender, uint256 indexed puid, bytes32 indexed vrfId, address owner, address token, address wallet, uint256 amount);
    event Finished(address indexed sender, uint256 ruid, uint256 indexed puid, bytes32 indexed vrfId, bool jackpot, uint256 payout, uint256 seed, uint256 fee, uint8[5] dice, uint8[5] picks);
    event Combo(address indexed sender,uint256 indexed puid, uint256 ruid, bytes32 indexed vrfId, uint8[5] dice, uint8[5] picks, uint256 reward);

    // @dev token events
    event TokensSent(address indexed sender, address _op, address _frm, address _to, uint256 _amt, bytes _usrdata, bytes _opdata );
    event TokensReceived(address indexed sender, address _op, address _frm, address _to, uint256 _amt, bytes _usrdata, bytes _opdata );
    
    /// @dev admin events
    event OwnerSet(address indexed sender, address indexed prev, address indexed current, uint256 puid);
    event ActiveSet(address indexed sender, bool prev, bool current, uint256 puid);   
    event CustomRollSet(address indexed sender, uint8[5] prev, uint8[5] curr, uint256 indexed puid);
    event PauseSet(address indexed sender);
    event UnPauseSet(address indexed sender);
         
}