// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

interface IIRollRNG {

    /// @dev VRF lifecycle events
    event VRFInit(address indexed sender, address coordinator, address token);
    event VRFRequested(address indexed sender, bytes32 indexed vrfId, uint256 indexed puid, uint256 started);
    event VRFFulfilled(address indexed sender, bytes32 indexed vrfId, uint256 indexed puid, uint256 finished);

    /// @dev only owner local parameter updates events
    event FeeSet(address indexed sender, uint256 prev, uint256 current);
    event KeyHashSet(address indexed sender, bytes32 prev, bytes32 current);
    event CallerContractSet(address indexed sender, address prev, address current);    

    /// @dev initiates request to VRF
    function request(uint256 _puid) external returns (bytes32);

    /// @dev call mock request for testing
    function mockRequest(uint256 _puid) external returns (bytes32);
    
    /// @dev get LINK token
    function getLink() external view returns(address);

    /// @dev get total request count
    function getRequestCount() external view returns(uint256);

    /// @dev get VRF Fee
    function getRequestFee() external view returns(address, uint256);

    /// @dev get balance of LINK contract holds for fees
    function getLinkBalance() external view returns(uint256);

    /// @dev set the contract that can call RNG
    function setCallerContract(address _contract) external;

    /// @dev set VRF Key Hash (ownerOnly)
    function setKeyHash(bytes32 _keyHash) external;

    /// @dev set VRF Key Hash (ownerOnly)
    function setFee(uint256 _fee) external;
}