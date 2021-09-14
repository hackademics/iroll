// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IIRollToken {

    event PauseSet(address indexed sender);
    event UnPauseSet(address indexed sender);   

    /// pause and unpause token contract
    function pause() external;
    function unpause() external;        
}