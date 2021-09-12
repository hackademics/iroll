// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interface/IIRollToken.sol";
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 

/** @dev Create IROLL Token and mint and transfer total supply to contract owner */
contract IRollToken is ERC777, Ownable, IIRollToken {    
    using SafeMath for *;
    using Address  for address; 
    using Counters for Counters.Counter;

    string internal _symbol = "IROLL";
    string internal _name = "IROLL.IO";
    string internal _version = "IROLL VERSION 1.0"; 
    address[] internal _operators;
    
    uint256 public _initialSupply = 2000000000;

    constructor() ERC777 (_name, _symbol, new address[](0)) {
        _mint(msg.sender, (_initialSupply * 10 ** 18), "", "");  
    } 

    function _beforeTokenTransfer(address _op, address _frm, address _to, uint256 _amt) internal virtual override {
        super._beforeTokenTransfer(_op, _frm, _to, _amt); 
    }         
}


