


/*
The total supply of LP tokens must always be greater than or equal to the minimum 
initial shares required for the first deposit:
This invariant ensures that the contract always has sufficient LP tokens to represent 
the liquidity of the pool. If the total supply of LP tokens falls below the minimum 
initial shares required for the first deposit, it means that there is not enough 
liquidity in the pool to support trading. This invariant should be checked after 
every deposit or withdrawal.



The contract must ensure that the deviation of the current liquidity from the target liquidity 
does not exceed a certain threshold before executing any function that involves modifying the 
liquidity of the pool:
This invariant ensures that the contract maintains the target liquidity range specified by the owner. 
Before executing any function that involves modifying the liquidity of the pool, the contract should 
check that the deviation of the current liquidity from the target liquidity does not exceed a certain 
threshold. This invariant should be checked before executing any function that modifies the liquidity 
of the pool.

The contract must not allow the protocol governance address to be changed:
This invariant ensures that the governance address of the protocol cannot be changed by anyone other 
than the contract owner. This is important for ensuring the security and stability of the protocol. 
This invariant should be checked for any function that allows the governance address to be modified.

uncompounded fee before rebalnce will always be greator then after rebalance

uncompounded fee before withdraw will always be greator then after withdraw

*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./SetupUAF.sol";
import { UnipilotActiveVault, IERC20 , IUnipilotVault} from "../UnipilotActiveVault.sol";

contract SetupUAV is SetupUAF {
    UnipilotActiveVault public UAV;
    bool init;
    address public pool;
    uint24 public fees;

    function FeeTier() private view returns (uint24) {
        uint24 LOW = 500; // 0.05% fee tier
        uint24 MEDIUM = 3000; // 0.30% fee tier
        uint24 HIGH = 10000; // 1.00% fee tier

        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
            )
        ) % 3;

        if (rand == 0) {
            return LOW;
        } else if (rand == 1) {
            return MEDIUM;
        } else {
            return HIGH;
        }
    }

    function encodePriceSqrt(uint256 reserve1, uint256 reserve0)
        private
        pure
        returns (uint160 encodedPriceSqrt)
    {
        require(reserve1 != 0 && reserve0 != 0, "ZERO");
        uint256 prod = reserve1 * 1e18;
        uint256 priceSqrt = 0;
        uint256 num = prod / reserve0;
        uint256 min = 0;
        uint256 max = (num + 1) / 2;
        while (min <= max) {
            uint256 mid = (min + max) / 2;
            if ((mid * mid) <= num) {
                priceSqrt = mid;
                min = mid + 1;
            } else {
                max = mid - 1;
            }
        }
        encodedPriceSqrt = uint160(priceSqrt << 96) / 1e9;
    }

    event here(string);
    event fee(uint24);
    event Sqrt(uint160);

    //Createting UnipilotActiveVault using UnipilotActiveFactory
    //Arbitary (valid in range) values been sent by echidna to fuzz different scenarios
    function testInit(
        address t0,
        address t1,
        uint256 amount0,
        uint256 amount1,
        uint16 _vaultStrategy
    ) public {
        require(init == false, "inited");
        uint160 _sqrtPriceX96 = encodePriceSqrt(amount0, amount1);
        fees = FeeTier();
        require(t0 != address(0) && _vaultStrategy < 5, "TV");
        emit Sqrt(_sqrtPriceX96);
        address vault = UAF.createVault(
            address(t0),
            address(t1),
            fees,
            _vaultStrategy,
            _sqrtPriceX96,
            "Fuzz",
            "fuzz"
        );

        assert(vault != address(0));
        UAV = UnipilotActiveVault(payable(vault));
        init = true;

        pool = factory.getPool(t0, t1, fees);
        address[] memory pools = new address[](1);
        uint16[] memory sTypes = new uint16[](1);
        int24[] memory bMults = new int24[](1);
        pools[0] = pool;
        sTypes[0] = _vaultStrategy;
        bMults[0] = 100;
        emit here("here");
        ST.setBaseTicks(pools, sTypes, bMults);
        ST.setMaxTwapDeviation(int24(9000));
        UAV.toggleOperator(msg.sender);
        
    }
    
    function getCurrentTick() public view returns(int24 tick) {
        ( , tick , , , , , ) = IUniswapV3Pool(pool).slot0();
    }

}
