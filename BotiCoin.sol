    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";

    contract BotiCoin is ERC20, Ownable {
        /**
        * @dev Constructor que inicializa el contrato del token.
        * @param initialSupply La cantidad inicial de tokens a crear.
        */
        constructor(uint256 initialSupply) ERC20("BotiCoin", "BOTI") Ownable(msg.sender) {
            _mint(msg.sender, initialSupply * (10 ** decimals()));
        }

        /**
        * @dev Función para crear más tokens (solo el dueño puede hacerlo).
        * @param to Dirección que recibirá los nuevos tokens.
        * @param amount Cantidad de tokens a crear.
        */
        function mint(address to, uint256 amount) public onlyOwner {
            _mint(to, amount);
        }

        /**
        * @dev Función para quemar tokens (eliminarlos de circulación).
        * @param amount Cantidad de tokens a quemar.
        */
        function burn(uint256 amount) public {
            _burn(msg.sender, amount);
        }
    }