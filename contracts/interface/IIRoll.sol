// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IIRoll {

    /// @dev holds settings for single Pot
    struct Pot {
        bool active; 
        address owner;
        address wallet;         
        uint8 seed;
        uint8 fee;
        uint8 sixes;
        uint8 picks;
        uint8 custom; 
        uint256 balance;           
        uint256 entry;
        uint256 interval;
        uint256 UID;
        uint8[5] customRoll;   
        uint256[11] rewards;
    }

    /// @dev holds data of single Roll for player
    struct Roll {
        bool jackpot;
        address player;
        bytes32 UID;
        uint256 vrfNum;          
        uint256 tokens;
        uint256 payout;
        uint256 fee;
        uint256 seed;
        uint256 PUID;
        uint8[5] dice;
        uint8[5] picks;               
    }

    /// @dev initiates a new roll for the player by requesting random number from Chainlink VRF
    function roll(uint256 _puid, uint8[5] calldata _pi) external payable returns(bytes32);

    /// @dev check if roll request satisfies pot interval; 
    function allowed(uint256 _puid) external view returns(bool);

    /// @dev create new pot - owner only
    function createPot(address _wallet, uint256 _entry, uint256 _intrv, uint8 _seed, uint8 _fee, uint8 _sxs, uint8 _pck, uint8 _cstm, uint8[5] calldata _crll, uint256[11] calldata _rwd) external returns(uint256);

    /// @dev get pot from pot array, revert if not found or not active
    function getPot(uint256 _puid) external view returns(Pot memory);

    /// @dev Only Admin can seed pot
    function seedPot(uint256 _puid) external payable;    

    /// @dev get current pot balance
    function getPotBalance(uint256 _puid) external view returns(uint256); 

    /// @dev get roll by UID
    function getRoll(bytes32 _ruid) external view returns (Roll memory);

    /// @dev get all rolls
    function getRolls() external view returns (Roll[] memory); 

    /// @dev get all rolls for pot  
    function getPotRolls(uint256 _puid) external view returns (Roll[] memory);  

    /// @dev update the pot's owner
    function setPotOwner(uint256 _puid, address _owner) external;

    /// @dev update pot active status
    function setPotActive(uint _puid, bool _active) external;

    /// @dev update pot custom roll
    function setPotRoll(uint _puid, uint8[5] calldata _pcr) external;

    /// @dev set pot wallet 
    function setPotWallet(uint _puid, address _wlt) external;      

    /// @dev events related to Pots
    event PotInit(address indexed ms, uint256 indexed puid, address wlt, uint256 ent, uint256 intrvl, uint8 sed, uint8 fee);
    event Seeded(address indexed ms,uint256 indexed puid, uint256 amt, uint256 bal, uint256 pbal);
    event SeedAlert(address indexed ms, uint256 indexed puid, uint256 pbal, uint256 adrbal);
    
    
    /// @dev events for the Roll lifecycle
    event RollInit(address indexed ms, bytes32 indexed ruid, uint256 indexed puid, uint256 pbal, uint256 adrbal);
    event VRF(address indexed ms, bytes32 indexed ruid, uint256 indexed puid);
    event Jackpot(address indexed ms, bytes32 indexed ruid, uint256 indexed puid, uint8[5] di, uint8[5] pi, uint256 rwd);
    event Combo(address indexed ms, bytes32 indexed ruid, uint256 indexed puid, uint8[5] di, uint8[5] pi, uint256 rwd);
    event Paid(address indexed ms, address indexed owner, bytes32 indexed ruid, uint256 puid, uint256 amt, uint256 sed, uint256 fee, uint256 pbal, uint256 adrbal);    
    event Reward(address indexed ms, bytes32 indexed ruid, uint256 indexed puid, address tkn, address wlt, uint256 amt);
    event Fin(address indexed ms, bytes32 indexed ruid, uint256 indexed puid, bool jp, uint256 amt, uint256 sed, uint256 fee, uint8[5] di, uint8[5] pi);
    
    // @dev token events
    event TokensSent(address indexed ms, address op, address frm, address to, uint256 amt, bytes usr, bytes opd );
    event TokensReceived(address indexed ms, address op, address frm, address to, uint256 amt, bytes usr, bytes opd );
    
    /// @dev admin events
    event OwnerSet(address indexed ms, uint256 indexed puid, address prv, address cur);
    event ActiveSet(address indexed ms, uint256 indexed puid, bool prv, bool cur);   
    event RollSet(address indexed ms, uint256 indexed puid, uint8[5] prv, uint8[5] cur);
    event PauseSet(address indexed ms, bool isPaused);
        
}