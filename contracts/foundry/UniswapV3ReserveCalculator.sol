// pragma solidity ^0.7.6;

// import "../dependencies/UniswapV3Pool.sol";
// import { UniswapLiquidityManagement } from "../libraries/UniswapLiquidityManagement.sol";

// contract UniswapV3ReserveCalculator {
//     using UniswapLiquidityManagement for IUniswapV3Pool;

//     function calculateReserves(
//         address poolAddress,
//         int24 baseTickLower,
//         int24 baseTickUpper
//     ) external returns (uint256 reserve0, uint256 reserve1) {
//         IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
//         (
//             uint256 amount0,
//             uint256 amount1,
//             uint256 fees0,
//             uint256 fees1,
//             uint128 liquidity
//         ) = pool.getReserves(
//                 baseTickLower,
//                 baseTickUpper
//             );
//         // (uint160 sqrtPriceX96,int24 currentTick , , , , , ) = pool.slot0();
//     }
// }
