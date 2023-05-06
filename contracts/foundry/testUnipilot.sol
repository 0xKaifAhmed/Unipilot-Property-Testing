//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../dependencies/UniswapV3Factory.sol";
import "../dependencies/WETH.sol";
import { UnipilotActiveFactory } from "../UnipilotActiveFactory.sol";
import { UnipilotStrategy } from "../UnipilotStrategy.sol";



contract indexfund {
    mapping(address => uint256) private balance0;
    mapping(address => uint256) private balance1;
}


contract testUnipiot {
    UniswapV3Factory factory;
    UnipilotActiveFactory public UAF;
    UnipilotStrategy ST;
    indexfund IF;
    WETH9 weth;

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
    }

}
