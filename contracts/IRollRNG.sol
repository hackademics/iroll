// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interface/IIRollRNG.sol";
import "./IRoll.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract IRollRNG is IIRollRNG, VRFConsumerBase, Ownable {
    using Counters for Counters.Counter;
    using Address  for address; 

    /// VRF Link Token
    address public vrfLinkToken;
    
    /// VRF Coordinator
    address public vrfCoordinator;

    /// VRF Key Hash
    bytes32 public vrfKeyHash;

    /// VRF Fee
    uint256 public vrfFee;

    /// IRoll contract that is allowed to call contract
    address public callerContract;

    /// total amount of requests made
    Counters.Counter public requestCount;    

    /// store the vrf request id for caller
    mapping(address => bytes32) mVRF;

    /// store the Pot UID for callback
    mapping(bytes32 => uint256) mPUID;

    /// store the msg.sender for callback
    mapping(bytes32 => address) mCaller;  

    constructor(address _token, address _coordinator) VRFConsumerBase(vrfCoordinator, vrfLinkToken)
    {   
        /// VRF Link Token
        vrfLinkToken = _token;

        /// VRF Coordinator
        vrfCoordinator = _coordinator;

        emit VRFInit(msg.sender, _coordinator, _token);
    }

    /// @dev make request to Chainlink VRF
    function request(uint256 _puid) public override returns (bytes32) {
        require(_puid > 0, "ids");
        require(msg.sender == callerContract, "caller");

        /// check LINK balance
        require(LINK.balanceOf(address(this)) >= vrfFee, "linkfee");

        /// increment request count
        requestCount.increment();         
        
        /// request random number from vrf
        bytes32 requestId = requestRandomness(vrfKeyHash, vrfFee);
        
        /// set Pot UID for access in callback
        mPUID[requestId] = _puid;

        /// set caller contract for callback
        mCaller[requestId] = msg.sender;
        
        emit VRFRequested(msg.sender, requestId, _puid, block.timestamp);
        
        return requestId;
    }   
    
    /// @dev handles return from VRF and forwards to request caller
    /// do not REVERT this method
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override{
        emit VRFFulfilled(msg.sender, requestId, mPUID[requestId], block.timestamp);
        //IRoll(mCaller[requestId]).vrfCallback(requestId, randomness, mPUID[requestId]);
    }  

    /// @dev MOCK REQUEST for testing.  REMOVE before MAINNET
    /// todo REMOVE
    function mockRequest(uint256 _puid, uint256 _ruid) public override onlyOwner returns (bytes32) {         
        require(_puid > 0 && _ruid > 0, "ids");  

        bytes32 requestId = keccak256(abi.encodePacked(block.difficulty, block.timestamp));
        uint256 randomness = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));

        IRoll(msg.sender).vrfCallback(requestId, randomness, _puid, _ruid);

        return requestId;
    }

    /// @dev get link token
    function getLink() public override view returns(address) {
        return address(LINK);
    }

    /// @dev get RNG request count
    function getRequestCount() public override view returns(uint256){
        return requestCount.current();
    }

    /// @dev get VRF request fee
    function getRequestFee() public override view returns(address, uint256){
        return (address(LINK), vrfFee); 
    }

    /// @dev get link balance for fees
    function getLinkBalance() public override view onlyOwner returns(uint256){
        return LINK.balanceOf(address(this));
    }    

    /// @dev set IROLL contract
    function setCallerContract(address _callerContract) public override onlyOwner {
        require(_callerContract.isContract(), "notcontract");
        emit CallerContractSet(msg.sender, callerContract, _callerContract);
        callerContract = _callerContract;
    }  

    /// @dev set VRF Key Hash
    function setKeyHash(bytes32 _keyHash) public override onlyOwner{
        require(_keyHash  > 0, "keyhash");
        emit KeyHashSet(msg.sender, vrfKeyHash, _keyHash);
        vrfKeyHash = _keyHash;
    }

    /// @dev set VRF Fee
    function setFee(uint256 _fee) public override onlyOwner{
        require(_fee > 0, "fee");
        emit FeeSet(msg.sender, vrfFee, _fee);
        vrfFee = _fee;
    }

}