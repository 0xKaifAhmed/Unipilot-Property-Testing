//SPDX-License-Identifier:MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../contracts/foundry/SetupUAV.sol";
import "../../contracts/foundry/Token.sol";
import { TransferHelper as TH } from "../../contracts/libraries/TransferHelper.sol";
import { UniswapLiquidityManagement as ULM } from "../../contracts/libraries/UniswapLiquidityManagement.sol";
import { IUniswapV3Pool as IV3pool } from "../../contracts/dependencies/interfaces/IUniswapV3Pool.sol";
import { UniswapV3Pool } from "../../contracts/dependencies/UniswapV3Pool.sol";
import { UniswapPoolActions } from "../../contracts/libraries/UniswapPoolActions.sol";

contract Fuzz is Test {
    SetupUAV fuzz;
    Token token0;
    Token token1;
    uint256 reserve0;
    uint256 reserve1;

    IV3pool public pool;
    using ULM for IUniswapV3Pool;
    using LowGasSafeMath for uint256;
    using UniswapPoolActions for IUniswapV3Pool;
    uint8 onlyonce;

    event lpShare(uint256);
    event balance(string, uint256);
    event tickData(string, int24);
    event liquidityAmount(string, uint128);

    function setUp() public {
        //minting tokens
        token0 = new Token(address(this));
        token1 = new Token(address(this));

        //deploying setup to fuzz
        fuzz = new SetupUAV();
        pool = IV3pool(fuzz.pool());

        //init test
        fuzz.Init(address(token0), address(token1), 1, 1, 1);
    }


    function _mint(int24 tl, int24 tu) private {
        UniswapV3Pool(fuzz.pool()).mint(
            address(this),
            tl,
            tu,
            1161916527027990527784,
            abi.encode(address(this))
        );
    }

    function uniswapV3MintCallback(
        uint256 t0,
        uint256 t1,
        bytes calldata data
    ) external {
        token0.transfer(fuzz.pool(), t1);
        token1.transfer(fuzz.pool(), t0);
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external {
        //  require(amount0 > 0 || amount1 > 0, "zero amount");
        bool zeroForOne = abi.decode(data, (bool));

        if (zeroForOne) {
            bool success = token1.transfer(msg.sender, uint256(amount0));
            require(success == true, "not transferred 0");
        } else {
            bool success = token0.transfer(msg.sender, uint256(amount1));
            require(success == true, "not transferred 1");
        }
    }

    function swapToken(bool zeroForOne, int256 amountSpecified) internal {
        (uint160 sqrtPriceX96, , , , , , ) = UniswapV3Pool(fuzz.pool()).slot0();

        uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (1e5 / 2)) / 1e6;

        uint160 sqrtPriceLimitX96 = zeroForOne
            ? sqrtPriceX96 - exactSqrtPriceImpact
            : sqrtPriceX96 + exactSqrtPriceImpact;

        UniswapV3Pool(fuzz.pool()).swap(
            address(this),
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(zeroForOne)
        );
    }

    function mintTokens() public {
        token0._mint(msg.sender, 1e18 ether);
        token1._mint(msg.sender, 1e18 ether);
    }

    function Deposit(
        uint256 amount0,
        uint256 amount1,
        address sender
    ) private returns (uint256 lp) {
        vm.roll(block.number + 100 minutes);
        require(token0.balanceOf(sender) > amount0);

        if (onlyonce == 0) {
            (int24 baseLower, int24 baseUpper, , , , ) = fuzz.ST().getTicks(
                fuzz.pool()
            );
            fuzz.UAV().rebalance(int256(0), false, baseLower, baseUpper);
            onlyonce = 1;
        }
        (lp, , ) = fuzz.UAV().deposit(amount0, amount1, sender);
        vm.roll(block.number + 100 minutes);
        // vm.warp(block.timestamp + 100 minutes);
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

    function Rebalance(uint8 swapAmount) private {
        vm.warp(block.timestamp + 100 minutes);
        (int24 baseLower, int24 baseUpper, , , , ) = fuzz.ST().getTicks(
            fuzz.pool()
        );
        fuzz.UAV().rebalance(swapAmount, true, baseLower, baseUpper);
        vm.warp(block.timestamp + 100 minutes);
    }

    ///////////////////////////////helper functions//////////////////////////////////
    function calculateShare(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 reserveAmount0,
        uint256 reserveAmount1,
        uint256 totalSupply
    ) internal view returns (uint256 shares, uint256 amount0, uint256 amount1) {
        if (totalSupply == 0) {
            // For first deposit, just use the amounts desired
            amount0 = amount0Max;
            amount1 = amount1Max;
            shares = amount0 > amount1 ? amount0 : amount1; // max
        } else if (reserveAmount0 == 0) {
            amount1 = amount1Max;
            shares = FullMath.mulDiv(amount1, totalSupply, reserveAmount1);
        } else if (reserveAmount1 == 0) {
            amount0 = amount0Max;
            shares = FullMath.mulDiv(amount0, totalSupply, reserveAmount0);
        } else {
            amount0 = FullMath.mulDiv(
                amount1Max,
                reserveAmount0,
                reserveAmount1
            );
            if (amount0 < amount0Max) {
                amount1 = amount1Max;
                shares = FullMath.mulDiv(amount1, totalSupply, reserveAmount1);
            } else {
                amount0 = amount0Max;
                amount1 = FullMath.mulDiv(
                    amount0,
                    reserveAmount1,
                    reserveAmount0
                );
                shares = FullMath.mulDiv(amount0, totalSupply, reserveAmount0);
            }
        }
    }

    function computePositionFee()
        internal
        returns (uint256 fees0, uint256 fees1)
    {
        vm.startPrank(address(fuzz.UAV()));
        (int24 btl, int24 btu, , ) = fuzz.UAV().ticksData();
        uint128 liquidity = UniswapPoolActions.updatePosition(
            fuzz.UAV().pool(),
            btl,
            btu,
            address(fuzz.UAV())
        );

        if (liquidity > 0) {
            (, , fees0, fees1) = ULM.collectableAmountsInPosition(
                fuzz.UAV().pool(),
                btl,
                btu,
                address(fuzz.UAV())
            );
        }
        vm.stopPrank();
    }

    function computeLpShares(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 balance0,
        uint256 balance1,
        uint256 totalSupply,
        int24 btl,
        int24 btu
    ) internal returns (uint256 shares, uint256 amount0, uint256 amount1) {
        vm.startPrank(address(fuzz.UAV()));
        uint128 liquidity = UniswapPoolActions.updatePosition(
            fuzz.UAV().pool(),
            btl,
            btu,
            address(fuzz.UAV())
        );

        emit tickData("Base tick lower", btl);
        emit tickData("Base tick upper", btu);
        emit liquidityAmount("Liquidity", liquidity);

        uint256 res0;
        uint256 res1;
        uint256 fees0;
        uint256 fees1;

        if (liquidity > 0) {
            (res0, res1, fees0, fees1) = ULM.collectableAmountsInPosition(
                fuzz.UAV().pool(),
                btl,
                btu,
                address(fuzz.UAV())
            );
        }

        reserve0 = res0.add(fees0).add(balance0);
        reserve1 = res1.add(fees1).add(balance1);
        emit balance("reserves 0", reserve0);
        emit balance("reserves 1", reserve1);
        // If total supply > 0, pool can't be empty
        // assert(totalSupply == 0 || reserve0 != 0 || reserve1 != 0);
        require(
            totalSupply == 0 || reserve0 != 0 || reserve1 != 0,
            "total supply"
        );

        (shares, amount0, amount1) = calculateShare(
            amount0Max,
            amount1Max,
            reserve0,
            reserve1,
            totalSupply
        );
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////////////////////

    /*
    Depositing tokens should increase the total supply of LP tokens and the balance of the 
    contract in both token0 and token1:
    This invariant ensures that the deposit function is working as intended. When tokens 
    are deposited into the contract, the total supply of LP tokens should increase, and the 
    balance of the contract in both token0 and token1 should also increase by the appropriate 
    amounts. This invariant should be checked after every deposit.
    */

    //invariant_checkLpSupplyBeforeAndAfterDeposit
    function test_1(uint256 amount0, uint256 amount1) public {
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
    //invariant_checkLpSupplyBeforeAndAfterWithdraw
    function test_2(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 1 ether, 1e10 ether);
        amount1 = bound(amount1, 1 ether, 1e10 ether);

        require(amount0 >= 1 ether && amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        mintTokens();
        uint256 lp = Deposit(amount0, amount1, address(this));
        vm.warp(block.timestamp + 100 minutes);

        uint256 preLP = fuzz.UAV()._totalSupply();
        Withdraw(lp, address(this), false);
        uint256 postLP = fuzz.UAV()._totalSupply();

        assert(preLP > postLP);
    }

    // Calculate the LP tokens accourding to the balance of t0 and t1 on unipilot position on
    // uniswap and make a bat while depositing the same amount through unipilot should be the same:
    // This invariant ensures that the LP tokens minted through Unipilot are accurately reflecting
    // the balance of token0 and token1 in the Unipilot position on Uniswap, and that there are no
    // discrepancies or unexpected errors in the calculation.
    // This invariant been written under the consideration when there is no liquidity minted.

    //invariant_MintedLpSameAsUnipilot
    function test_3A(uint256 Amount0, uint256 Amount1) public {
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

    //This invariant been written under the consideration when there is liquidity already minted.
    //invariant_MintedLp_Reserves
    function test_3B(uint256 Amount0, uint256 Amount1) public {
        //PreConditions
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        // calculate LP shares of amount getting deposite according to previous deposits
        (int24 btl, int24 btu, , ) = fuzz.UAV().ticksData();
        (uint256 Selflp, , ) = computeLpShares(
            Amount0,
            Amount1,
            fuzz.UAV()._balance0(),
            fuzz.UAV()._balance1(),
            fuzz.UAV()._totalSupply(),
            btl,
            btu
        );
        //then actually deposit that amount
        vm.warp(block.timestamp + 100);
        uint256 Unipilotlp = Deposit(Amount0, Amount1, address(this));

        emit lpShare(Selflp);
        emit lpShare(Unipilotlp);
        assertEq(Selflp, Unipilotlp);
    }

    //invariant_MintedLp_ReservesAndFee
    function test_3C(
        uint256 Amount0,
        uint256 Amount1,
        uint256 swapAmount
    ) public {
        //PreConditions
        //PreConditions
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        swapAmount = bound(swapAmount, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        vm.warp(block.timestamp + 100);
        Deposit(100 ether, 100 ether, address(this));
        vm.warp(block.timestamp + 100);
        (int24 baseLower, int24 baseUpper, , , , ) = fuzz.ST().getTicks(
            fuzz.pool()
        );

        _mint(baseLower - 1000, baseUpper + 1000);
        vm.warp(block.timestamp + 100);

        swapToken(true, int256(swapAmount));
        vm.warp(block.timestamp + 100);

        (int24 btl, int24 btu, , ) = fuzz.UAV().ticksData();
        (uint256 Selflp, , ) = computeLpShares(
            Amount0,
            Amount1,
            fuzz.UAV()._balance0(),
            fuzz.UAV()._balance1(),
            fuzz.UAV()._totalSupply(),
            btl,
            btu
        );
        console.log(reserve0);
        console.log(reserve1);
        console.log(fuzz.UAV()._totalSupply());

        //then actually deposit that amount
        uint256 Unipilotlp = Deposit(Amount0, Amount1, address(this));

        //check if you get the same amount
        emit lpShare(Selflp);
        emit lpShare(Unipilotlp);
        assertEq(Selflp, Unipilotlp);
    }

    // A - B = ut-lt , A = tickHigher - currentTick, B = currentTick - lowerTick ---
    // -- after rebalce (PostCondition)
    // ut-ct = x
    // ct-lt = y
    // ut-lt = z
    // x+y = z

    //invariant_Ticks
    function test_4(
        uint256 Amount0,
        uint256 Amount1,
        uint256 swapAmount
    ) public {
        //PreConditions
        Amount0 = bound(Amount0, 100 ether, 1e10 ether);
        Amount1 = bound(Amount1, 100 ether, 1e10 ether);
        swapAmount = bound(swapAmount, 100 ether, 1e10 ether);
        require(Amount0 >= 100 ether && Amount1 >= 100 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        vm.warp(block.timestamp + 100);
        Deposit(100 ether, 100 ether, address(this));
        vm.warp(block.timestamp + 100);
        (int24 baseLower, int24 baseUpper, , , , ) = fuzz.ST().getTicks(
            fuzz.pool()
        );

        _mint(baseLower - 1000, baseUpper + 1000);
        vm.warp(block.timestamp + 100);

        vm.prank(address(this));
        swapToken(true, int256(swapAmount));
        Rebalance(uint8(swapAmount));

        (int24 btl, int24 btu, , ) = fuzz.UAV().ticksData();

        int24 currentTick = fuzz.getCurrentTick();
        int24 A = btu - currentTick;
        int24 B = currentTick - btl;
        int24 diff = btu - btl;
        int24 add = A + B;
        assertEq(diff, add, "not equal");
    }

    //Post deposit Lps should be less then pre deposit Lp because of compounded fees
    //invariant_Diff_Lps
    function test_5(
        uint256 Amount0,
        uint256 Amount1,
        uint256 swapAmount
    ) public {
        //PreConditions
        Amount0 = bound(Amount0, 100 ether, 1e10 ether);
        Amount1 = bound(Amount1, 100 ether, 1e10 ether);
        swapAmount = bound(swapAmount, 100 ether, 1e10 ether);
        require(Amount0 >= 100 ether && Amount1 >= 100 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        uint256 preLP = Deposit(Amount0, Amount1, address(this));
        vm.warp(block.timestamp + 100);
        Deposit(100 ether, 100 ether, address(this));
        vm.warp(block.timestamp + 100);
        (int24 baseLower, int24 baseUpper, , , , ) = fuzz.ST().getTicks(
            fuzz.pool()
        );

        _mint(baseLower - 1000, baseUpper + 1000);
        vm.warp(block.timestamp + 100);

        vm.prank(address(this));
        swapToken(true, int256(swapAmount));
        Rebalance(uint8(swapAmount));

        vm.warp(block.timestamp + 100);
        uint256 postLP = Deposit(Amount0, Amount1, address(this));

        require(preLP > postLP, "Improper LP minting");
    }

    //Make liquidity lot of range
    //call readjust liquidity
    //get ticks from ST
    //assert position back in range

    //invariant_liquidityBackInRange
    function test_6(
        uint256 Amount0,
        uint256 Amount1,
        uint256 swapAmount
    ) public {
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        swapAmount = bound(swapAmount, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        vm.warp(block.timestamp + 100);
        Deposit(100 ether, 100 ether, address(this));
        vm.warp(block.timestamp + 100);
        (int24 btl, int24 btu, , , , ) = fuzz.ST().getTicks(fuzz.pool());

        //minting on Uniswap to create depth in pool
        for (int24 i; i < 10; i++) {
            _mint(btl - 20000, btu + 20000);
            vm.warp(block.timestamp + 100);
        }
        //too much swaps will make liquidity out of range
        for (uint i; i < 20; i++) {
            swapToken(true, int256(swapAmount));
            vm.warp(block.timestamp + 100);
        }

        //Making position back in range
        Rebalance(uint8(50));

        //making sure that position is back in range 
        (int24 tickLower, int24 tickUpper, , ) = fuzz.UAV().ticksData();
        int24 currentTick = fuzz.getCurrentTick();
        assert(tickLower < currentTick);
        assert(tickUpper > currentTick);
    }

    //test coumpounded fee is zero after withdraw/rebalance
    //invariant_rebalnce will make all fee back in position
    function test_7(
        uint256 Amount0,
        uint256 Amount1,
        uint256 swapAmount
    ) public {
        //Using bounded model
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
        swapAmount = bound(swapAmount, 1 ether, 1e10 ether);
        require(Amount0 >= 1 ether && Amount1 >= 1 ether, "Saving From ML");
        require(address(token0) != address(0), "Mint tokens First");

        //generating Lp tokens to withdraw
        uint256 lp = Deposit(Amount0, Amount1, address(this));
        vm.warp(block.timestamp + 100);
        lp += Deposit(100 ether, 100 ether, address(this));
        vm.warp(block.timestamp + 100);
        (int24 btl, int24 btu, , , , ) = fuzz.ST().getTicks(fuzz.pool());

        //minting on Uniswap to create depth in pool
        for (int24 i; i < 10; i++) {
            _mint(btl - 20000, btu + 20000);
            vm.warp(block.timestamp + 100);
        }
        //swaps will generate fees to the unipilot position
        for (uint i; i < 20; i++) {
            swapToken(true, int256(swapAmount));
            vm.warp(block.timestamp + 100);
        }

        //getting position fee
        (uint256 preFee0, uint256 preFee1) = computePositionFee();
        //making sure that position has generated some fee from swaps
        assert(preFee0 != 0 || preFee1 != 0);

        //withdraw operation will compound fee
        vm.warp(block.timestamp + 100 minutes);
        Withdraw(lp, address(this), false);

        //this makes sure that now unipilot has no fee in position
        (uint256 postFee0, uint256 postFee1) = computePositionFee();
        assertEq(postFee0, postFee1);

    }
}
