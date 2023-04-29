//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./testUnipilot.sol";
import "../dependencies/libraries/SafeMath.sol";
import { UnipilotActiveVault } from "../UnipilotActiveVault.sol";

contract UnipilotFuzz is testUnipiot {
    using SafeMath for uint256;

    address t0;
    address t1;
    UnipilotActiveVault public UAV;

    event notmytoken(address);

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

    function gettokens() private {
        (t0, t1) = createToken(msg.sender);
    }

    function encodePriceSqrt(
        uint256 reserve1,
        uint256 reserve0
    ) private pure returns (uint160 encodedPriceSqrt) {
        uint256 priceSqrt = SafeMath
            .sqrt(reserve1.mul(1e18).div(reserve0))
            .mul(2 ** 96)
            .div(1e9);
        encodedPriceSqrt = uint160(priceSqrt);
    }

    event here(string);
    event fee(uint24);
    event Sqrt(uint160);

    //Createting UnipilotActiveVault using UnipilotActiveFactory
    //Arbitary (valid in range) values been sent by echidna to fuzz different scenarios
    function testAddressValidity(
        uint256 amount0,
        uint256 amount1,
        uint16 _vaultStrategy
    ) public {
        uint160 _sqrtPriceX96 = encodePriceSqrt(amount0, amount1);
        gettokens();
        uint24 fees = FeeTier();
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
    }

    /*
    Depositing tokens should increase the total supply of LP tokens and the balance of the 
    contract in both token0 and token1:
    This invariant ensures that the deposit function is working as intended. When tokens 
    are deposited into the contract, the total supply of LP tokens should increase, and the 
    balance of the contract in both token0 and token1 should also increase by the appropriate 
    amounts. This invariant should be checked after every deposit.
    */
    function testLpIncrease(uint256 amount0, uint256 amount1) public {
        uint256 preLP = UAV._totalSupply();
        require(amount0 >= 1 ether || amount1 >= 1 ether, "Saving From ML");
        UAV.deposit(amount0, amount1, msg.sender);
        uint256 postLP = UAV._totalSupply();
        assert(preLP < postLP);
    }
}

/*
The total supply of LP tokens must always be greater than or equal to the minimum 
initial shares required for the first deposit:
This invariant ensures that the contract always has sufficient LP tokens to represent 
the liquidity of the pool. If the total supply of LP tokens falls below the minimum 
initial shares required for the first deposit, it means that there is not enough 
liquidity in the pool to support trading. This invariant should be checked after 
every deposit or withdrawal.

Calculate the LP tokens accourding to the balance of t0 and t1 on unipilot position on 
uniswap and make a bat while depositing the same amount through unipilot should be the same:
This invariant ensures that the LP tokens minted through Unipilot are accurately reflecting 
the balance of token0 and token1 in the Unipilot position on Uniswap, and that there are no 
discrepancies or unexpected errors in the calculation.

Withdrawing LP tokens should decrease the total supply of LP tokens and the balance of 
the contract in both token0 and token1, and should result in the correct amounts of token0 
and token1 being transferred to the recipient:
This invariant ensures that the withdrawal function is working as intended. When LP tokens 
are withdrawn from the contract, the total supply of LP tokens should decrease, and the 
balance of the contract in both token0 and token1 should decrease by the appropriate amounts. 
The correct amounts of token0 and token1 should also be transferred to the recipient. 
This invariant should be checked after every withdrawal.

The operator must be approved before executing any function that requires operator approval:
This invariant ensures that the operator approval system is working as intended. 
Functions that require operator approval should only be executed if the operator has been 
approved by the contract owner. This invariant should be checked before executing any function 
that requires operator approval.

The contract must not allow reentrant calls:
This invariant ensures that the contract is protected against reentrancy attacks. Reentrancy 
attacks occur when a function can be called recursively before the initial call has completed, 
which can lead to unexpected behavior and potentially allow an attacker to drain the contract's 
funds. This invariant should be checked for every function in the contract.

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


dollor value before rebalnce is always greator then after rebalce because of fee 

uncompounded fee before rebalnce will always be greator then after rebalance

uncompounded fee before withdraw will always be greator then after rebalance

A - B != 0 before rebalce/withdraw ---------- false assumption (PreCondition)
A - B = 0 , A = tickHiher - currentTick, B = currentTick - lowerTick ----- after rebalce/withdraw (PostCondition)
*/
