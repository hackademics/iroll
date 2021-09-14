// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";

/// USE CONTRACT TO LOCK TOKENS FOR VESTING
contract IRollTokenLock is TokenTimelock, Ownable {
    
    event TokenLocked(address indexed sender, address token, address wallet, uint256 releaseEpoch);
    
    constructor(IERC20 token, address wallet, uint256 releaseEpoch) TokenTimelock(token, wallet, releaseEpoch) {
        require(wallet != address(0), "wallet");
        emit TokenLocked(msg.sender, address(token), wallet, releaseEpoch);
    }
}