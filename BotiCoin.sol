// Ejemplo para BotiCoin.sol (aplicar lo mismo a PepaCoin.sol)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BotiCoin is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("BotiCoin", "BOTI") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * 10**decimals()); 
    }

    function mint(address to, uint256 amount) external onlyOwner { 
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
