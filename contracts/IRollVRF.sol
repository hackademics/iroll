// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./IRoll.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; 

contract IRollVRF is VRFConsumerBase {
    address private coordinator;
    address private linkToken;
    bytes32 private keyHash;
    uint256 private fee;

    mapping(bytes32 => address) caller;

    constructor(address _vrfLinkToken, address _vrfCoord, bytes32 _vrfKeyHash, uint256 _vrfFee) VRFConsumerBase(_vrfCoord, _vrfLinkToken){
        coordinator = _vrfCoord;
        linkToken = _vrfLinkToken;
        keyHash = _vrfKeyHash;
        fee = _vrfFee;
    }

    function request() public returns(bytes32){
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        IRoll(address(this)).rollResponse(requestId, randomness);
    }

    function mockRequest(bytes32 _requestId) public returns(bytes32){
        caller[_requestId] = msg.sender;
        uint256 randomness = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))); 
        IRoll(caller[_requestId]).rollResponse(_requestId, randomness);
        return _requestId;
    }
}