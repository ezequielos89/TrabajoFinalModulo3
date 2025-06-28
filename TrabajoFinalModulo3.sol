// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TrabajoPracticoModulo3 is ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    struct Pool {
        uint256 reserveA;
        uint256 reserveB;
        uint256 lastUpdateTimestamp;
    }

    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant PROTOCOL_FEE = 3; // 0.3%
    
    mapping(address => mapping(address => Pool)) public pools;

    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB
    );

    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    /**
    * @dev Inicializa el contrato del DEX y el token LP (SSLP)
    * Crea un nuevo token ERC20 para representar las participaciones en los pools de liquidez
    * El token tendrá nombre "SimpleSwap LP Token" y símbolo "SSLP"
    */
    constructor() ERC20("SimpleSwap LP Token", "SSLP") {}

    // ========== MODIFIERS ========== //
    modifier checkDeadline(uint256 deadline) {
        require(deadline == 0 || deadline >= block.timestamp, "Expired");
        _;
    }

    // ========== MAIN FUNCTIONS ========== //
       /**
    * @dev Permite a un usuario añadir liquidez a un pool de tokens
    * @param tokenA Dirección del primer token del par
    * @param tokenB Dirección del segundo token del par
    * @param amountADesired Cantidad deseada del token A a depositar
    * @param amountBDesired Cantidad deseada del token B a depositar
    * @param amountAMin Cantidad mínima aceptable de token A
    * @param amountBMin Cantidad mínima aceptable de token B
    * @param to Dirección que recibirá los tokens LP
    * @param deadline Límite de tiempo para ejecutar la transacción
    * @return amountA Cantidad real de token A depositada
    * @return amountB Cantidad real de token B depositada
    * @return liquidity Cantidad de tokens LP recibidos
    * 
    * Requisitos:
    * - Los tokens deben ser diferentes
    * - Las cantidades deben ser positivas
    * - Se deben respetar los mínimos especificados
    * - El deadline no debe haber expirado
    */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        _validateInputs(tokenA, tokenB, to);
        require(amountADesired > 0 && amountBDesired > 0, "Invalid amounts");
        
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        
        (amountA, amountB) = _calculateOptimalAmounts(
            amountADesired,
            amountBDesired,
            pool.reserveA,
            pool.reserveB,
            amountAMin,
            amountBMin
        );
        
        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);
        
        liquidity = _mintLiquidityTokens(amountA, amountB, pool.reserveA, pool.reserveB);
        
        _updatePoolReserves(pool, amountA, amountB);
        _mint(to, liquidity);
        
        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }
    /**
    * @dev Permite a un usuario retirar liquidez de un pool
    * @param tokenA Dirección del primer token del par
    * @param tokenB Dirección del segundo token del par
    * @param liquidity Cantidad de tokens LP a quemar
    * @param amountAMin Cantidad mínima aceptable de token A a recibir
    * @param amountBMin Cantidad mínima aceptable de token B a recibir
    * @param to Dirección que recibirá los tokens retirados
    * @param deadline Límite de tiempo para ejecutar la transacción
    * @return amountA Cantidad de token A recibida
    * @return amountB Cantidad de token B recibida
    * 
    * Requisitos:
    * - Los tokens deben ser diferentes
    * - El usuario debe tener suficientes tokens LP
    * - Se deben respetar los mínimos especificados
    *  - El deadline no debe haber expirado
    */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) returns (uint256 amountA, uint256 amountB) {
        _validateInputs(tokenA, tokenB, to);
        
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        
        (amountA, amountB) = _calculateWithdrawalAmounts(liquidity, pool.reserveA, pool.reserveB);
        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient amounts");
        
        _burn(msg.sender, liquidity);
        _decreasePoolReserves(pool, amountA, amountB);
        
        _safeTransfer(tokenA, to, amountA);
        _safeTransfer(tokenB, to, amountB);
        
        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }
    /**
    * @dev Realiza un swap de una cantidad exacta de tokens por otra cantidad mínima esperada
    * @param amountIn Cantidad exacta de tokens a enviar
    * @param amountOutMin Cantidad mínima de tokens esperada a recibir
    * @param path Array de direcciones de tokens que representa la ruta de swap
    * @param to Dirección que recibirá los tokens resultantes
    * @param deadline Límite de tiempo para ejecutar la transacción
    * @return amounts Array con las cantidades en cada paso del swap
    * 
    * Requisitos:
    * - La ruta debe tener al menos 2 tokens
    * - El resultado debe ser mayor o igual que amountOutMin
    * - El deadline no debe haber expirado
    */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        amounts = _getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output");
        
        _safeTransferFrom(path[0], msg.sender, address(this), amounts[0]);
        _swap(amounts, path, to);
    }

    // ========== VIEW FUNCTIONS ========== //
    /**
    * @dev Obtiene el precio de un token en términos del otro
    * @param tokenA Dirección del primer token
    * @param tokenB Dirección del segundo token
    * @return price Precio del tokenA en términos de tokenB, normalizado a 18 decimales
    * 
    * Nota: Considera las diferencias en decimales entre los tokens
    * El precio se calcula como (reservaB * 10^(18+decimalsA)) / (reservaA * 10^decimalsB)
    */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        Pool storage pool = pools[token0][token1];
        
        uint8 decimalsA = IERC20Metadata(tokenA).decimals();
        uint8 decimalsB = IERC20Metadata(tokenB).decimals();
        
        price = tokenA == token0
            ? pool.reserveB.mul(10**(18 + decimalsA)).div(pool.reserveA.mul(10**decimalsB))
            : pool.reserveA.mul(10**(18 + decimalsB)).div(pool.reserveB.mul(10**decimalsA));
    }
    /**
    * @dev Calcula la cantidad de tokens de salida dada una cantidad de entrada y reservas
    * @param amountIn Cantidad de tokens de entrada
    * @param reserveIn Reserva actual del token de entrada
    * @param reserveOut Reserva actual del token de salida
    * @return amountOut Cantidad estimada de tokens de salida
    * 
    * Fórmula: amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee)
    * donde amountInWithFee = amountIn * (FEE_DENOMINATOR - PROTOCOL_FEE)
    * La tarifa de protocolo es del 0.3% (PROTOCOL_FEE = 3, FEE_DENOMINATOR = 1000)
    */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint256 amountInWithFee = amountIn.mul(FEE_DENOMINATOR.sub(PROTOCOL_FEE));
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
        amountOut = numerator.div(denominator);
    }

    // ========== INTERNAL FUNCTIONS ========== //
    function _validateInputs(
        address tokenA,
        address tokenB,
        address to
    ) internal pure {
        require(tokenA != tokenB, "Identical tokens");
        require(to != address(0), "Invalid recipient");
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _calculateOptimalAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal pure returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = amountADesired.mul(reserveB).div(reserveA);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = amountBDesired.mul(reserveA).div(reserveB);
                require(amountAOptimal >= amountAMin, "Insufficient A");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _mintLiquidityTokens(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB
    ) internal view returns (uint256 liquidity) {
        if (totalSupply() == 0) {
            liquidity = Math.sqrt(amountA.mul(amountB));
        } else {
            liquidity = Math.min(
                amountA.mul(totalSupply()).div(reserveA),
                amountB.mul(totalSupply()).div(reserveB)
            );
        }
        require(liquidity > 0, "Insufficient liquidity");
    }

    function _calculateWithdrawalAmounts(
        uint256 liquidity,
        uint256 reserveA,
        uint256 reserveB
    ) internal view returns (uint256 amountA, uint256 amountB) {
        amountA = liquidity.mul(reserveA).div(totalSupply());
        amountB = liquidity.mul(reserveB).div(totalSupply());
    }

    function _updatePoolReserves(
        Pool storage pool,
        uint256 amountA,
        uint256 amountB
    ) internal {
        pool.reserveA = pool.reserveA.add(amountA);
        pool.reserveB = pool.reserveB.add(amountB);
        pool.lastUpdateTimestamp = block.timestamp;
    }

    function _decreasePoolReserves(
        Pool storage pool,
        uint256 amountA,
        uint256 amountB
    ) internal {
        pool.reserveA = pool.reserveA.sub(amountA);
        pool.reserveB = pool.reserveB.sub(amountB);
        pool.lastUpdateTimestamp = block.timestamp;
    }

    function _getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        for (uint256 i; i < path.length - 1; i++) {
            (address tokenIn, address tokenOut) = (path[i], path[i + 1]);
            (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
            Pool storage pool = pools[token0][token1];
            
            (uint256 reserveIn, uint256 reserveOut) = tokenIn == token0 
                ? (pool.reserveA, pool.reserveB) 
                : (pool.reserveB, pool.reserveA);
            
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address tokenIn, address tokenOut) = (path[i], path[i + 1]);
            (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
            Pool storage pool = pools[token0][token1];
            
            (uint256 amountIn, uint256 amountOut) = (amounts[i], amounts[i + 1]);
            
            if (tokenIn == token0) {
                pool.reserveA = pool.reserveA.add(amountIn);
                pool.reserveB = pool.reserveB.sub(amountOut);
            } else {
                pool.reserveB = pool.reserveB.add(amountIn);
                pool.reserveA = pool.reserveA.sub(amountOut);
            }
            
            _safeTransfer(tokenOut, to, amountOut);
            emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        }
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }
}