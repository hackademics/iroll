// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IIRoll {

    /// @dev holds settings for single Pot
    struct Pot {
        bool active; 
        bool sixes;
        bool picks;
        bool custom; 
        uint8 seed;
        uint8 fee;                
        address owner;
        address wallet;
        uint256 balance;           
        uint256 entry;
        uint256 interval;
        uint256 UID;
        uint8[5] customRoll;   
        uint256[11] rewards;
    }

    /// @dev holds data of single Roll for player
    // struct Roll {
    //     bool jackpot;
    //     address player;
    //     bytes32 vrfId;
    //     uint256 vrfNum; 
    //     uint256 UID;                 
    //     uint256 tokens;
    //     uint256 payout;
    //     uint256 fee;
    //     uint256 seed;
    //     uint256 PUID;
    //     uint8[5] dice;
    //     uint8[5] picks;               
    // }

    /// @dev initiates a new roll for the player by requesting random number from Chainlink VRF
    function roll(uint256 _puid, uint8[5] calldata _pi) external payable returns(bytes32);

    /// @dev check if roll request satisfies pot interval; 
    function allowed(uint256 _puid) external view returns(bool);

    /// @dev create new pot - owner only
    function createPot(uint256 _entry, uint256 _intrv, uint8 _seed, uint8 _fee, bool _sxs, bool _pck, bool _cstm, uint8[5] calldata _crll, uint256[11] calldata _rwd) external returns(uint256);
    
    /// @dev Only Admin can seed pot
    function seedPot(uint256 _puid) external payable;  

    /// @dev get pot from pot array, revert if not found or not active
    function getPot(uint256 _puid) external view returns(Pot memory);  

    /// @dev get a list of pots
    function getPots() external view returns(uint256[] memory); 

    /// @dev get player token balance
    function getPlayerBalance() external view returns(uint256);

    /// @dev get contract token balance
    function getRewardBalance() external view returns(uint256);

    /// @dev update the pot's owner
    function setPotOwner(uint256 _puid, address _owner) external;

    /// @dev update pot active status
    function setPotActive(uint _puid, bool _active) external;      


    event Rolls (
        address indexed plyr, 
        bytes32 indexed vrfid, 
        uint256 indexed puid,       
        bool jp, 
        uint256 amt, 
        uint256 rwd, 
        uint8[5] di, 
        uint8[5] pi
    );   

    event Jackpot(
        address indexed plyr, 
        bytes32 indexed vrfid, 
        uint256 indexed puid, 
        uint8[5] di, 
        uint8[5] pi,
        uint256 payout, 
        uint256 rwd
    );  

    event TokensReceived(address indexed ms, address op, address frm, address to, uint256 amt, bytes usr, bytes opd );   
    
    /// @dev admin events
    event OwnerSet(address indexed ms, uint256 indexed puid, address prv, address cur);
    event ActiveSet(address indexed ms, uint256 indexed puid, bool prv, bool cur);   
    event RollSet(address indexed ms, uint256 indexed puid, uint8[5] prv, uint8[5] cur);
    event PauseSet(address indexed ms, bool isPaused);
        
}