// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract Fether is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint decimal = 10** decimals();
    mapping(address => uint ) timeToReset;
    constructor(address another) ERC20("Fether", "FETH") {
        _mint(msg.sender, 1000000 * decimal);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE , another);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function faucet(address to ) public {
        require(timeToReset[to] < block.timestamp , "You need to check again after 24 hours");
        _mint(to , 100 * decimal);
        timeToReset[to] = block.timestamp + 1 days;

        
    }

    
}