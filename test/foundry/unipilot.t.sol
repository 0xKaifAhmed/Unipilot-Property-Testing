//SPDX-License-Identifier:MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../contracts/foundry/SetupUAV.sol";
import "../../contracts/foundry/Token.sol";
import {UniswapLiquidityManagement as ULM} from "../../contracts/libraries/UniswapLiquidityManagement.sol";
import {IUniswapV3Pool as IV3pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";


contract Fuzz is Test {
    SetupUAV fuzz;
    Token token0;
    Token token1;
    IV3pool public pool;
    using ULM for IUniswapV3Pool;
    using LowGasSafeMath for uint256;


    // rc public RC;

    function setUp() public {
        token0 = new Token(address(this));
        token1 = new Token(address(this));
        fuzz = new SetupUAV();
        pool = IV3pool(fuzz.pool());
        fuzz.testInit(address(token0), address(token1), 1, 1, 1);
    }

    function mintTokens() public {
        token0._mint(msg.sender, 1e18 ether);
        token1._mint(msg.sender, 1e18 ether);
    }

    function getMinTick(int24 tickSpacing) private pure returns (int24) {
        return (-22974 / tickSpacing + 1) * tickSpacing;
    }

    function getMaxTick(int24 tickSpacing) private pure returns (int24) {
        return (22974 / tickSpacing) * tickSpacing;
    }

    function Deposit(
        uint256 amount0,
        uint256 amount1,
        address sender
    ) private returns (uint256 lp) {
        require(token0.balanceOf(sender) > amount0);
        uint8 onlyonce = 0;
        if (onlyonce == 0) {
            fuzz.UAV().rebalance(
                int256(0),
                false,
                -int24(getMinTick(60)),
                int24(getMaxTick(60))
            );
            onlyonce = 1;
        }
        (lp, , ) = fuzz.UAV().deposit(amount0, amount1, sender);
    }

    function Withdraw(
        uint256 liquidity,
        address recipient,
        bool refundAsETH
    ) private {
        require(
            fuzz.UAV().balanceOf(recipient) >= liquidity,
            "Insifficient LPs"
        );
        fuzz.UAV().withdraw(liquidity, recipient, refundAsETH);
    }

    ////////////////////////////////////////////////////////////////////////////////

    function testMain(uint256 amount0, uint256 amount1) public {
        console.log("Address", address(fuzz.UAV()));
        require(address(fuzz.UAV()) != address(0), "Contract not created");
        invariant_MintedLp_Reserves(amount0, amount1);
    }

    /*
    Depositing tokens should increase the total supply of LP tokens and the balance of the 
    contract in both token0 and token1:
    This invariant ensures that the deposit function is working as intended. When tokens 
    are deposited into the contract, the total supply of LP tokens should increase, and the 
    balance of the contract in both token0 and token1 should also increase by the appropriate 
    amounts. This invariant should be checked after every deposit.
    */
    function invariant_checkLpSupplyBeforeAndAfterDeposit(
        uint256 amount0,
        uint256 amount1
    ) public {
        amount0 = bound(amount0, 1 ether, 1e10 ether);
        amount1 = bound(amount1, 1 ether, 1e10 ether);

        require(amount0 >= 1 ether && amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        mintTokens();
        uint256 preLP = fuzz.UAV()._totalSupply();
        Deposit(amount0, amount1, address(this));
        uint256 postLP = fuzz.UAV()._totalSupply();

        assert(preLP < postLP);
    }

    /*
Withdrawing LP tokens should decrease the total supply of LP tokens and the balance of 
the contract in both token0 and token1, and should result in the correct amounts of token0 
and token1 being transferred to the recipient:
This invariant ensures that the withdrawal function is working as intended. When LP tokens 
are withdrawn from the contract, the total supply of LP tokens should decrease, and the 
balance of the contract in both token0 and token1 should decrease by the appropriate amounts. 
The correct amounts of token0 and token1 should also be transferred to the recipient. 
This invariant should be checked after every withdrawal.
*/
    function invariant_checkLpSupplyBeforeAndAfterWithdraw(
        uint256 amount0,
        uint256 amount1
    ) public {
        amount0 = bound(amount0, 1 ether, 1e10 ether);
        amount1 = bound(amount1, 1 ether, 1e10 ether);

        require(amount0 >= 1 ether && amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        mintTokens();
        uint256 lp = Deposit(amount0, amount1, address(this));
        vm.roll(block.number + 10);

        uint256 preLP = fuzz.UAV()._totalSupply();
        Withdraw(lp, address(this), false);
        uint256 postLP = fuzz.UAV()._totalSupply();

        assert(preLP > postLP);
    }

    event lpShare(uint256);

    //This invariant been written under the consideration when there is no liquidity minted.
    function invariant_MintedLpSameAsUnipilot(
        uint256 Amount0,
        uint256 Amount1
    ) public {
        //PreConditions
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //calculate LP shares of amount getting deposite according to previous deposits
        uint256 bal0 = token0.balanceOf(address(fuzz.UAV()));
        uint256 bal1 = token1.balanceOf(address(fuzz.UAV()));
        (uint256 Selflp, , ) = calculateShare(
            Amount0,
            Amount1,
            bal0,
            bal1,
            fuzz.UAV()._totalSupply()
        );

        //then actually deposit that amount
        mintTokens();
        uint256 Unipilotlp = Deposit(Amount0, Amount1, address(this));

        //check if you get the same amount
        emit lpShare(Selflp);
        emit lpShare(Unipilotlp);
        assertEq(Selflp, Unipilotlp);
    }

    event tickData(string,int24);
    //This invariant been written under the consideration when there is liquidity already minted.
    function invariant_MintedLp_Reserves(
        uint256 Amount0,
        uint256 Amount1
    ) public {
        //PreConditions
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        (int24 btl, int24 btu, int24 rtl, int24 rtu ) = fuzz.UAV().ticksData();
       // calculate LP shares of amount getting deposite according to previous deposits
        (
            uint256 baseAmount0,
            uint256 baseAmount1,
            ,
            ,
        ) = ULM.getReserves(
                IV3pool(fuzz.pool()),
                btl,
                btu
            );

        (
            uint256 rangeAmount0,
            uint256 rangeAmount1,
            ,
            ,
        ) = ULM.getReserves(
                IV3pool(fuzz.pool()),
                rtl,
                rtu
            );

        uint256 reserve0 = baseAmount0.add(rangeAmount0).add(fuzz.UAV()._balance0());
        uint256 reserve1 = baseAmount1.add(rangeAmount1).add(fuzz.UAV()._balance1());

        (uint256 Selflp, , ) = calculateShare(
            Amount0,
            Amount1,
            reserve0,
            reserve1,
            fuzz.UAV()._totalSupply()
        );

        //then actually deposit that amount
        mintTokens();
        uint256 Unipilotlp = Deposit(Amount0, Amount1, address(this));

        //check if you get the same amount
        emit lpShare(Selflp);
        emit lpShare(Unipilotlp);
        assertEq(Selflp, Unipilotlp);
    }

    function invariant_MintedLp_ReservesAndFee(
        uint256 Amount0,
        uint256 Amount1
    ) public {
        //PreConditions
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        (int24 btl, int24 btu, int24 rtl, int24 rtu ) = fuzz.UAV().ticksData();
       // calculate LP shares of amount getting deposite according to previous deposits
        (
            uint256 baseAmount0,
            uint256 baseAmount1,
            ,
            ,
        ) = ULM.getReserves(
                IV3pool(fuzz.pool()),
                btl,
                btu
            );

        (
            uint256 rangeAmount0,
            uint256 rangeAmount1,
            ,
            ,
        ) = ULM.getReserves(
                IV3pool(fuzz.pool()),
                rtl,
                rtu
            );

        uint256 reserve0 = baseAmount0.add(rangeAmount0).add(fuzz.UAV()._balance0());
        uint256 reserve1 = baseAmount1.add(rangeAmount1).add(fuzz.UAV()._balance1());

        (uint256 Selflp, , ) = calculateShare(
            Amount0,
            Amount1,
            reserve0,
            reserve1,
            fuzz.UAV()._totalSupply()
        );

        //then actually deposit that amount
        mintTokens();
        uint256 Unipilotlp = Deposit(Amount0, Amount1, address(this));

        //check if you get the same amount
        emit lpShare(Selflp);
        emit lpShare(Unipilotlp);
        assertEq(Selflp, Unipilotlp);
    }

/////////////////////////////////helper functions/////////////////////////////////////////

    function calculateShare(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) internal pure returns (uint256 shares, uint256 amount0, uint256 amount1) {
        if (totalSupply == 0) {
            // For first deposit, just use the amounts desired
            amount0 = amount0Max;
            amount1 = amount1Max;
            shares = amount0 > amount1 ? amount0 : amount1; // max
        } else if (reserve0 == 0) {
            amount1 = amount1Max;
            shares = FullMath.mulDiv(amount1, totalSupply, reserve1);
        } else if (reserve1 == 0) {
            amount0 = amount0Max;
            shares = FullMath.mulDiv(amount0, totalSupply, reserve0);
        } else {
            amount0 = FullMath.mulDiv(amount1Max, reserve0, reserve1);
            if (amount0 < amount0Max) {
                amount1 = amount1Max;
                shares = FullMath.mulDiv(amount1, totalSupply, reserve1);
            } else {
                amount0 = amount0Max;
                amount1 = FullMath.mulDiv(amount0, reserve1, reserve0);
                shares = FullMath.mulDiv(amount0, totalSupply, reserve0);
            }
        }
    }
}
