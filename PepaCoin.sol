// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PepaCoin is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("PepaCoin", "PEPA") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * 10**decimals()); // Eliminamos paréntesis redundantes
    }

    function mint(address to, uint256 amount) external onlyOwner { // Cambiado a external
        _mint(to, amount);
    }

    function burn(uint256 amount) external { // Cambiado a external
        _burn(msg.sender, amount);
    }
}
