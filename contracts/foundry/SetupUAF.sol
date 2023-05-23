//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../dependencies/UniswapV3Factory.sol";
import { NonfungibleTokenPositionDescriptor, INonfungiblePositionManager } from "../dependencies/periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import { NonfungiblePositionManager } from "../dependencies/periphery/contracts/NonfungiblePositionManager.sol";
import "../dependencies/WETH.sol";
import { UnipilotActiveFactory } from "../UnipilotActiveFactory.sol";
import { UnipilotStrategy } from "../UnipilotStrategy.sol";

contract indexfund {
    mapping(address => uint256) private balance0;
    mapping(address => uint256) private balance1;
}

contract SetupUAF {
    UniswapV3Factory public factory;
    NonfungibleTokenPositionDescriptor TokenDescriptor;
    NonfungiblePositionManager public PositionManager;
    UnipilotActiveFactory public UAF;
    UnipilotStrategy public ST;
    indexfund IF;
    WETH9 public weth;

    constructor() {
        factory = new UniswapV3Factory();
        ST = new UnipilotStrategy(address(this));
        IF = new indexfund();
        weth = new WETH9();
        UAF = new UnipilotActiveFactory(
            address(factory),
            address(this),
            address(ST),
            address(IF),
            address(weth),
            1
        );
        deployUniswap();
    }

    bytes32 nativeCurrencyLabelBytes = bytes32("UniswapV3");

    function deployUniswap() private {
        TokenDescriptor = new NonfungibleTokenPositionDescriptor(
            address(weth),
            nativeCurrencyLabelBytes
        );
        PositionManager = new NonfungiblePositionManager(
            address(factory),
            address(weth),
            address(TokenDescriptor)
        );
    }

    // function mintToUniswap(
    //     address t0,
    //     address t1,
    //     uint24 fees,
    //     int24 tl,
    //     int24 tu,
    //     uint256 amount0,
    //     uint256 amount1,
    //     address sender
    // ) public {
    //     (address tokenA, address tokenB) = t0 < t1
    //         ? (t0, t1)
    //         : (t1, t0);

    //     PositionManager.mint(
    //         INonfungiblePositionManager.MintParams({
    //             token0: tokenA,
    //             token1: tokenB,
    //             fee: fees,
    //             tickLower: tl,
    //             tickUpper: tu,
    //             amount0Desired: amount0,
    //             amount1Desired: amount1,
    //             amount0Min: 0,
    //             amount1Min: 0,
    //             recipient: sender,
    //             deadline: block.timestamp + 900
    //         })
    //     );
    // }
}
