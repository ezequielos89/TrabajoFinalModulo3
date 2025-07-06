// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TrabajoPracticoModulo3 is ERC20("SimpleSwap LP Token", "SSLP") {
    struct Pool {
        uint256 reserveA;
        uint256 reserveB;
        uint256 lastUpdateTimestamp;
    }

    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant PROTOCOL_FEE = 3;
    uint256 private constant FEE_FACTOR = 997;
    
    mapping(address => mapping(address => Pool)) public pools;

    event LiquidityAdded(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event Swap(address indexed sender, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    modifier checkDeadline(uint256 deadline) {
        require(deadline == 0 || deadline >= block.timestamp, "Expired");
        _;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external checkDeadline(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(tokenA != tokenB && to != address(0), "Invalid input");
        require(amountADesired > 0 && amountBDesired > 0, "Invalid amounts");
        
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Pool memory pool = pools[token0][token1];
        
        (amountA, amountB) = _calculateLiquidityAmounts(
            amountADesired,
            amountBDesired,
            pool.reserveA,
            pool.reserveB,
            amountAMin,
            amountBMin
        );
        
        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);
        
        liquidity = _calculateLiquidity(amountA, amountB, pool.reserveA, pool.reserveB);
        
        pools[token0][token1] = Pool(
            pool.reserveA + amountA,
            pool.reserveB + amountB,
            block.timestamp
        );
        
        _mint(to, liquidity);
        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external checkDeadline(deadline) returns (uint256 amountA, uint256 amountB) {
        require(tokenA != tokenB && to != address(0), "Invalid input");
        
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Pool memory pool = pools[token0][token1];
        
        uint256 _totalSupply = totalSupply();
        amountA = (liquidity * pool.reserveA) / _totalSupply;
        amountB = (liquidity * pool.reserveB) / _totalSupply;
        
        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient amounts");
        
        _burn(msg.sender, liquidity);
        
        pools[token0][token1] = Pool(
            pool.reserveA - amountA,
            pool.reserveB - amountB,
            block.timestamp
        );
        
        _safeTransfer(tokenA, to, amountA);
        _safeTransfer(tokenB, to, amountB);
        
        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external checkDeadline(deadline) returns (uint256[] memory amounts) {
        require(path.length >= 2 && to != address(0), "Invalid input");
        
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        for (uint256 i; i < path.length - 1;) {
            (address tokenIn, address tokenOut) = (path[i], path[i + 1]);
            (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
            Pool memory pool = pools[token0][token1];
            
            (uint256 reserveIn, uint256 reserveOut) = tokenIn == token0 
                ? (pool.reserveA, pool.reserveB) 
                : (pool.reserveB, pool.reserveA);
            
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            
            if (tokenIn == token0) {
                pools[token0][token1] = Pool(
                    pool.reserveA + amounts[i],
                    pool.reserveB - amounts[i + 1],
                    block.timestamp
                );
            } else {
                pools[token0][token1] = Pool(
                    pool.reserveA - amounts[i + 1],
                    pool.reserveB + amounts[i],
                    block.timestamp
                );
            }
            
            unchecked { ++i; }
        }
        
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output");
        
        _safeTransferFrom(path[0], msg.sender, address(this), amounts[0]);
        _safeTransfer(path[path.length - 1], to, amounts[amounts.length - 1]);
        
        emit Swap(msg.sender, path[0], path[path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public pure returns (uint256 amountOut) 
    {
        uint256 amountInWithFee = amountIn * FEE_FACTOR;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }


    function getPrice(address tokenA, address tokenB) external view returns (uint256) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Pool memory pool = pools[token0][token1];
        uint256 reserveA = tokenA == token0 ? pool.reserveA : pool.reserveB;
        uint256 reserveB = tokenA == token0 ? pool.reserveB : pool.reserveA;
        return (reserveB * 1e18) / reserveA;
    }

    function _calculateLiquidityAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal pure returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            return (amountADesired, amountBDesired);
        }
        
        uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
        if (amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, "Insufficient B");
            return (amountADesired, amountBOptimal);
        }
        
        uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
        require(amountAOptimal >= amountAMin, "Insufficient A");
        return (amountAOptimal, amountBDesired);
    }

    function _calculateLiquidity(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB
    ) internal view returns (uint256 liquidity) {
        if (totalSupply() == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = (amountA * totalSupply()) / reserveA;
            uint256 liquidityB = (amountB * totalSupply()) / reserveB;
            if (liquidityB < liquidity) liquidity = liquidityB;
        }
        require(liquidity > 0, "Insufficient liquidity");
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }
}
