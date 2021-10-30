// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IRollToken is ERC20, Ownable {    
    using SafeERC20 for IERC20;
    
    constructor(string memory _symbol, string memory _name, uint256 _supply) ERC20 (_name, _symbol) {
        _mint(msg.sender, (_supply * 10 ** 18));  
    }       
}


