
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Decentralized Exchange (DEX) - Automated Market Maker
 * @dev A simple constant product AMM (x * y = k) for token swapping
 */
contract Project {
    // State variables
    address public owner;
    uint public reserveToken0;
    uint public reserveToken1;
    uint public totalLiquidity;
    mapping(address => uint) public liquidityBalance;
    
    // Constants
    uint public constant MINIMUM_LIQUIDITY = 1000;
    uint public constant FEE_PERCENT = 3; // 0.3% fee
    
    // Events
    event LiquidityAdded(address indexed provider, uint amountToken0, uint amountToken1, uint liquidity);
    event LiquidityRemoved(address indexed provider, uint amountToken0, uint amountToken1, uint liquidity);
    event Swap(address indexed user, uint amountIn, uint amountOut, bool token0ToToken1);
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Add liquidity to the pool
     * @param amountToken0 Amount of token0 to add
     * @param amountToken1 Amount of token1 to add
     * @return liquidity Amount of liquidity tokens minted
     */
    function addLiquidity(uint amountToken0, uint amountToken1) external payable returns (uint liquidity) {
        require(amountToken0 > 0 && amountToken1 > 0, "Invalid amounts");
        
        if (totalLiquidity == 0) {
            // Initial liquidity
            liquidity = sqrt(amountToken0 * amountToken1);
            require(liquidity > MINIMUM_LIQUIDITY, "Insufficient initial liquidity");
            totalLiquidity = liquidity;
        } else {
            // Subsequent liquidity must maintain price ratio
            uint liquidity0 = (amountToken0 * totalLiquidity) / reserveToken0;
            uint liquidity1 = (amountToken1 * totalLiquidity) / reserveToken1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
            totalLiquidity += liquidity;
        }
        
        liquidityBalance[msg.sender] += liquidity;
        reserveToken0 += amountToken0;
        reserveToken1 += amountToken1;
        
        emit LiquidityAdded(msg.sender, amountToken0, amountToken1, liquidity);
    }
    
    /**
     * @dev Remove liquidity from the pool
     * @param liquidity Amount of liquidity tokens to burn
     * @return amountToken0 Amount of token0 returned
     * @return amountToken1 Amount of token1 returned
     */
    function removeLiquidity(uint liquidity) external returns (uint amountToken0, uint amountToken1) {
        require(liquidity > 0, "Invalid liquidity amount");
        require(liquidityBalance[msg.sender] >= liquidity, "Insufficient liquidity balance");
        
        amountToken0 = (liquidity * reserveToken0) / totalLiquidity;
        amountToken1 = (liquidity * reserveToken1) / totalLiquidity;
        
        require(amountToken0 > 0 && amountToken1 > 0, "Insufficient liquidity burned");
        
        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveToken0 -= amountToken0;
        reserveToken1 -= amountToken1;
        
        payable(msg.sender).transfer(amountToken0 + amountToken1);
        
        emit LiquidityRemoved(msg.sender, amountToken0, amountToken1, liquidity);
    }
    
    /**
     * @dev Swap tokens using constant product formula (x * y = k)
     * @param amountIn Amount of input token
     * @param token0ToToken1 Direction of swap (true = token0 to token1, false = token1 to token0)
     * @return amountOut Amount of output token
     */
    function swap(uint amountIn, bool token0ToToken1) external payable returns (uint amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveToken0 > 0 && reserveToken1 > 0, "Insufficient liquidity");
        
        uint amountInWithFee = amountIn * (1000 - FEE_PERCENT);
        
        if (token0ToToken1) {
            // Swap token0 for token1
            amountOut = (amountInWithFee * reserveToken1) / (reserveToken0 * 1000 + amountInWithFee);
            require(amountOut < reserveToken1, "Insufficient output amount");
            
            reserveToken0 += amountIn;
            reserveToken1 -= amountOut;
            
            payable(msg.sender).transfer(amountOut);
        } else {
            // Swap token1 for token0
            amountOut = (amountInWithFee * reserveToken0) / (reserveToken1 * 1000 + amountInWithFee);
            require(amountOut < reserveToken0, "Insufficient output amount");
            
            reserveToken1 += amountIn;
            reserveToken0 -= amountOut;
            
            payable(msg.sender).transfer(amountOut);
        }
        
        emit Swap(msg.sender, amountIn, amountOut, token0ToToken1);
    }
    
    /**
     * @dev Get current reserves
     * @return reserve0 Token0 reserve
     * @return reserve1 Token1 reserve
     */
    function getReserves() external view returns (uint reserve0, uint reserve1) {
        return (reserveToken0, reserveToken1);
    }
    
    /**
     * @dev Calculate output amount for a given input
     * @param amountIn Input amount
     * @param token0ToToken1 Swap direction
     * @return amountOut Expected output amount
     */
    function getAmountOut(uint amountIn, bool token0ToToken1) external view returns (uint amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveToken0 > 0 && reserveToken1 > 0, "No liquidity");
        
        uint amountInWithFee = amountIn * (1000 - FEE_PERCENT);
        
        if (token0ToToken1) {
            amountOut = (amountInWithFee * reserveToken1) / (reserveToken0 * 1000 + amountInWithFee);
        } else {
            amountOut = (amountInWithFee * reserveToken0) / (reserveToken1 * 1000 + amountInWithFee);
        }
    }
    
    /**
     * @dev Square root function for liquidity calculation
     */
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // Fallback function to receive ETH
    receive() external payable {}
}
