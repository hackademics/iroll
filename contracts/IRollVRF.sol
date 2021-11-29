// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./IRoll.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; 

contract IRollVRF is VRFConsumerBase, Ownable {
    using Address  for address; 
    bytes32 private keyHash;
    uint256 private fee;
    address private callerContract;

    mapping(bytes32 => address) caller;

    constructor(address _vrfLinkToken, address _vrfCoord, bytes32 _vrfKeyHash, uint256 _vrfFee) VRFConsumerBase(_vrfCoord, _vrfLinkToken){
        keyHash = _vrfKeyHash;
        fee = _vrfFee;
    }   

    function request(address _linkWallet) public returns(bytes32){
        //require(LINK.balanceOf(address(this)) >= fee, "bad fee");
        //LINK.transferFrom(_linkWallet, address(this), fee);        
        bytes32 requestId = requestRandomness(keyHash, fee);
        caller[requestId] = msg.sender;
        return requestId;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        //require(msg.sender == coordinator, 'invalid');
        IRoll(caller[requestId]).rollResponse(requestId, randomness);
    }

    function withdraw() public onlyOwner {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "bad withdraw");
    }    

    function mockRequest(bytes32 _requestId) public returns(bytes32){
        require(msg.sender == callerContract, "bad contract");
        caller[_requestId] = msg.sender;
        uint256 randomness = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))); 
        IRoll(caller[_requestId]).rollResponse(_requestId, randomness);
        return _requestId;
    }

    function getLinkBalance() public view returns(uint256){
        return LINK.balanceOf(address(this));
    }

    function setCallerContract(address _contract) public onlyOwner {
        require(_contract.isContract(), "bad contract");
        callerContract = _contract;
    }      

    function setFee(uint256 _fee) public onlyOwner{
        require(_fee > 0, "bad fee");
        fee = _fee;
    }
}