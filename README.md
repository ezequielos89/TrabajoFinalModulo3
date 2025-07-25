# TrabajoFinalModulo3
Trabajo práctico - Contrato SimpleSwap y tokens ERC20

Hash de transaccion: (con el swapverifier)
0xc0fa7d91d1cc9806e6b4b52c70fdbddc4278b0805502feae50eefe5bbdaddf92
authors N°120 "EZE"
 
Implementación de un DEX simple (SimpleSwap) y dos tokens ERC20 (BotiCoin y PepaCoin).

## Contenido
- `SimpleSwap.sol`: Contrato del exchange descentralizado
- `BotiCoin.sol`: Implementación del token BotiCoin (BOTI)
- `PepaCoin.sol`: Implementación del token PepaCoin (PEPA)

## Funcionalidades del SimpleSwap
✅ Añadir/remover liquidez  
✅ Swap entre tokens  
✅ Calculadora de precios  
✅ Tarifa de protocolo del 0.3%  
✅ Tokens LP para proveedores de liquidez  

## Tecnologías
- Solidity ^0.8.0
- OpenZeppelin Contracts


## Cómo probar
1. Compilar en Remix o con Hardhat
2. Desplegar los contratos en este orden:
   ```
   1. BotiCoin.deploy
   2. PepaCoin.deploy
   3. SimpleSwap.deploy()
   ```
3. Interactuar con las funciones del DEX

## Licencia
MIT License
