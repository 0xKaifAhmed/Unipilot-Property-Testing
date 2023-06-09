//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../dependencies/UniswapV3Factory.sol";
import { NonfungibleTokenPositionDescriptor, INonfungiblePositionManager } from "../dependencies/periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import { NonfungiblePositionManager } from "../dependencies/periphery/contracts/NonfungiblePositionManager.sol";
import "../dependencies/WETH.sol";
import { UnipilotActiveFactory } from "../UnipilotActiveFactory.sol";
import { UnipilotStrategy } from "../UnipilotStrategy.sol";

contract indexfund {}

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
}
