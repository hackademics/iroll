// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./IRoll.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; 

/// @title VRF Request and Response handler
/// @author Richard Waldvogel
/// @notice Handle requests and reponse for Chainlink VRF random number generation
contract IRollVRF is VRFConsumerBase, Ownable {
    using Address  for address; 
    bytes32 private keyHash;
    uint256 private fee;
    address private callerContract;

    mapping(bytes32 => address) caller;

    /// @notice Initialize VRFConsumerBase Contract 
    /// @param _vrfLinkToken LINK Token Address
    /// @param _vrfCoord LINK VRF Coordinator Address
    /// @param _vrfKeyHash LINK VRF Key Hash
    /// @param _vrfFee LINK VRF Fee per request
    constructor(address _vrfLinkToken, address _vrfCoord, bytes32 _vrfKeyHash, uint256 _vrfFee) VRFConsumerBase(_vrfCoord, _vrfLinkToken){
        keyHash = _vrfKeyHash;
        fee = _vrfFee;
    }   

    /// @notice Request handler for random number
    /// @dev fullfillRandomness handles response from VRF and returns to calling contract address
    /// @param _linkWallet Address to pay for VRF Request
    /// @return bytes32 VRF Request Id
    function request(address _linkWallet) public returns(bytes32){
        //require(LINK.balanceOf(address(this)) >= fee, "bad fee");
        //LINK.transferFrom(_linkWallet, address(this), fee);        
        bytes32 requestId = requestRandomness(keyHash, fee);
        caller[requestId] = msg.sender;
        return requestId;
    }

    /// @notice Response handler for VRF random number request - Override
    /// @dev Do not throw ex and forward values to calling contract
    /// @param _requestId VRF Request Id
    /// @param _randomness VRF Random Number
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        //require(msg.sender == coordinator, 'invalid');
        IRoll(caller[requestId]).rollResponse(_requestId, _randomness);
    }

    /// @notice Transfer balance to Owner - Only Owner
    function withdraw() public onlyOwner {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "bad withdraw");
    }    

    /// @notice Testing method for local development
    /// @param _requestId Mock VRF Request Id
    /// @return bytes32 of Mock VRF Request Id
    function mockRequest(bytes32 _requestId) public returns(bytes32){
        require(msg.sender == callerContract, "bad contract");
        caller[_requestId] = msg.sender;
        uint256 randomness = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))); 
        IRoll(caller[_requestId]).rollResponse(_requestId, randomness);
        return _requestId;
    }

    /// @notice Return LINK Balance for contract
    /// @return uint256 of LINK balance of 'this' address
    function getLinkBalance() public view returns(uint256){
        return LINK.balanceOf(address(this));
    }

    /// @notice Update address of allowed contract address - Only Owner
    /// @param _contract Address of the contract allowed to call contract
    function setCallerContract(address _contract) public onlyOwner {
        require(_contract.isContract(), "bad contract");
        callerContract = _contract;
    }      

    /// @notice Update LINK Fee amount - Only Owner
    /// @param _fee VRF Fee amount
    function setFee(uint256 _fee) public onlyOwner{
        require(_fee > 0, "bad fee");
        fee = _fee;
    }
}