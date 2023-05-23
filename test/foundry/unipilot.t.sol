//SPDX-License-Identifier:MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../contracts/foundry/SetupUAV.sol";
import "../../contracts/foundry/Token.sol";
import { TransferHelper as TH } from "../../contracts/libraries/TransferHelper.sol";
import { UniswapLiquidityManagement as ULM } from "../../contracts/libraries/UniswapLiquidityManagement.sol";
import { IUniswapV3Pool as IV3pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { SwapRouter } from "../../contracts/dependencies/periphery/contracts/SwapRouter.sol";
import { UniswapV3Pool } from "../../contracts/dependencies/UniswapV3Pool.sol";

contract Swaper {
    ISwapRouter public immutable swapRouter;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    function swapExactInputSingle(
        uint256 amountIn,
        address _tokenIn,
        address _tokenOut,
        uint24 fees
    ) external returns (uint256 amountOut) {
        TH.safeTransferFrom(_tokenIn, msg.sender, address(this), amountIn);

        TH.safeApprove(_tokenIn, address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: fees,
                recipient: msg.sender,
                deadline: block.timestamp + 10 minutes,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }
}

contract Fuzz is Test {
    SetupUAV fuzz;
    Token token0;
    Token token1;
    uint256 reserve0;
    uint256 reserve1;
    IV3pool public pool;
    SwapRouter public swapRouter;
    Swaper public swap;
    using ULM for IUniswapV3Pool;
    using LowGasSafeMath for uint256;
    uint8 onlyonce;

    function setUp() public {
        //minting tokens
        token0 = new Token(address(this));
        token1 = new Token(address(this));

        //deploying setup to fuzz
        fuzz = new SetupUAV();
        pool = IV3pool(fuzz.pool());

        //deploying router
        swapRouter = new SwapRouter(
            address(fuzz.factory()),
            address(fuzz.weth())
        );
        swap = new Swaper(ISwapRouter(address(swapRouter)));

        //init test
        fuzz.testInit(address(token0), address(token1), 1, 1, 1);
        int24 currentTick = fuzz.getCurrentTick();
        console.log(
            "this is the current tick ///////////////////////////////////////"
        );
        console.logInt(currentTick);
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
        uint256 a,
        uint256 b,
        bytes calldata data
    ) external {
        token0.transfer(fuzz.pool(), a);
        token1.transfer(fuzz.pool(), b);
    }

      function swapToken(
        bool zeroForOne,
        int256 amountSpecified
    ) internal {
        (uint160 sqrtPriceX96, , , , , ,) = UniswapV3Pool(fuzz.pool()).slot0();

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

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external {

         require(amount0 > 0 || amount1 > 0, "zero amount");
        bool zeroForOne = abi.decode(data, (bool));

        if (zeroForOne) {
            emit balance("token 0 at address this", token0.balanceOf(address(this)));
           bool success = token0.transferFrom(address(this),msg.sender, uint256(amount0));
           require(success == true , "not transferred 0");

           
        } else {
            emit balance("token 1 at address this", token1.balanceOf(address(this)));
            bool success = token1.transferFrom(address(this),msg.sender, uint256(amount1));
            require(success == true , "not transferred 1");

        }
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
        vm.roll(block.number + 100);
        require(token0.balanceOf(sender) > amount0);

        if (onlyonce == 0) {
            (int24 baseLower, int24 baseUpper, , , , ) = fuzz.ST().getTicks(
                fuzz.pool()
            );
            fuzz.UAV().rebalance(int256(0), false, baseLower, baseUpper);
            onlyonce = 1;
        }
        (lp, , ) = fuzz.UAV().deposit(amount0, amount1, sender);
        vm.roll(block.number + 100);
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
        fuzz.UAV().rebalance(swapAmount, true, int24(-1000), int24(1000));
        vm.warp(block.timestamp + 100 minutes);
        //  fuzz.UAV().readjustLiquidity(swapAmount);
    }

    ////////////////////////////////////////////////////////////////////////////////

    function testMain(uint256 amount0, uint256 amount1) public {
        console.log("Address", address(fuzz.UAV()));
        console.log("router address", address(swapRouter));
        require(address(fuzz.UAV()) != address(0), "Contract not created");
        // invariant_MintedLp_ReservesAndFee(amount0, amount1);
        invariant_Ticks(amount0, amount1);
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
    event balance(string, uint256);

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

    event tickData(string, int24);

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
        (int24 btl, int24 btu, int24 rtl, int24 rtu) = fuzz.UAV().ticksData();
        // calculate LP shares of amount getting deposite according to previous deposits
        (uint256 baseAmount0, uint256 baseAmount1, , , ) = ULM.getReserves(
            IV3pool(fuzz.pool()),
            btl,
            btu
        );

        (uint256 rangeAmount0, uint256 rangeAmount1, , , ) = ULM.getReserves(
            IV3pool(fuzz.pool()),
            rtl,
            rtu
        );

        reserve0 = baseAmount0.add(rangeAmount0).add(fuzz.UAV()._balance0());
        reserve1 = baseAmount1.add(rangeAmount1).add(fuzz.UAV()._balance1());

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

        //Depositing preLiqudity to hit the second condtion of calculateLpShares
        Deposit(Amount0, Amount1, address(this));
        //swapInLoop(1, address(token0), address(token1));
        token0.approve(address(swap), 100 ether);
        swap.swapExactInputSingle(
            0.1 ether,
            address(token0),
            address(token1),
            3000
        );
        // swapInLoop(1, address(token1), address(token0));

        calculateReservesAndFee();

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

    //A - B = 0 , A = tickHigher - currentTick, B = currentTick - lowerTick ---
    //-- after rebalce/withdraw (PostCondition)
    function invariant_Ticks(uint256 Amount0, uint256 Amount1) public {
        //PreConditions
        Amount0 = bound(Amount0, 1 ether, 1e10 ether);
        Amount1 = bound(Amount1, 1 ether, 1e10 ether);
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
        //swapInLoop(1, address(token1), address(token0));
        vm.warp(block.timestamp + 100);

        vm.prank(address(this));
        swapToken(true,1 ether);
       // Rebalance(0);

        (int24 btl, int24 btu, , ) = fuzz.UAV().ticksData();

        int24 currentTick = fuzz.getCurrentTick();

        assert(((btu - currentTick) - (currentTick - btl)) == 0);
    }

    /////////////////////////////////helper functions/////////////////////////////////////////

    function calculateShare(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 reserveAmount0,
        uint256 reserveAmount1,
        uint256 totalSupply
    ) internal pure returns (uint256 shares, uint256 amount0, uint256 amount1) {
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

    function calculateReservesAndFee() private {
        (int24 btl, int24 btu, int24 rtl, int24 rtu) = fuzz.UAV().ticksData();
        // calculate LP shares of amount getting deposite according to previous deposits
        (
            uint256 baseAmount0,
            uint256 baseAmount1,
            uint256 baseFee0,
            uint256 baseFee1,

        ) = ULM.getReserves(IV3pool(fuzz.pool()), btl, btu);

        (
            uint256 rangeAmount0,
            uint256 rangeAmount1,
            uint256 rangeFee0,
            uint256 rangeFee1,

        ) = ULM.getReserves(IV3pool(fuzz.pool()), rtl, rtu);

        reserve0 = baseAmount0
            .add(rangeAmount0)
            .add(baseFee0)
            .add(rangeFee0)
            .add(fuzz.UAV()._balance0());

        reserve1 = baseAmount1
            .add(rangeAmount1)
            .add(baseFee1)
            .add(rangeFee1)
            .add(fuzz.UAV()._balance1());
    }

    function swapInLoop(
        uint256 loop,
        address tokenin,
        address tokenout
    ) private returns (uint256 amountout) {
        for (uint256 i = 0; i < loop; i++) {
            uint256 amountin = 1 ether;
            uint24 fee = fuzz.fees();
            amountout = swap.swapExactInputSingle(
                amountin,
                tokenin,
                tokenout,
                fee
            );
            vm.roll(block.number + 10);
        }
    }
}
