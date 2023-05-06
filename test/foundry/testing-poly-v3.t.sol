//SPDX-License-Identifier:MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";

import "contracts/UnipilotActiveVault.sol";
// import "";
import "contracts/UnipilotStrategy.sol";
import "contracts/interfaces/IUnipilotFactory.sol";

import "contracts/test/IndexFund.sol";
import "contracts/test/WETH9.sol";

import "../../contracts/test/MYERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract ContractTest is Test {
    using SafeMath for uint256;

    IUnipilotFactory public activeFactory;
    address public activeVault;

    address _uniStrategy;

    IUniswapV3Factory _algebraFactory;
    address _governance;

    IndexFund _indexFund;

    WETH9 _WETH;
    uint8 percentage;

    address _timelockAddress;
    address[] _lockedFundAddresses;

    address user1;
    address user2;
    address user3;

    address nfp;

    MyERC20 token0;
    MyERC20 token1;
    address t0;
    address t1;

    address[] depositors;
    address[] depositorsOnUnipilot;
    address[] swappers;

    SwapExamples public swap;
    uint128[] liquidityAfterDeposits;
    uint256[] liquidityAfterDepositsOnUnipilot;

    address pool;

    function setUp() public {
        _governance = 0x1E3881227010c8DcDFa2F11833D3d70A00893f94;

        _algebraFactory = IUniswapV3Factory(
            0x1F98431c8aD98523631AE4a59f267346ea31F984
        );
        vm.label(address(_algebraFactory), "AlgebraFactory");

        _uniStrategy = address(new UnipilotStrategy(_governance));
        vm.label(address(_uniStrategy), "UnipilotStrategy");

        _timelockAddress = vm.addr(4);

        address ch1 = vm.addr(5);
        address ch2 = vm.addr(6);

        user1 = vm.addr(7);
        user2 = vm.addr(8);
        user3 = vm.addr(1982398);

        _lockedFundAddresses = [ch1, ch2];

        _indexFund = new IndexFund(_timelockAddress, _lockedFundAddresses);
        vm.label(address(_indexFund), "IF::");

        _WETH = new WETH9();

        percentage = 3;

        activeFactory = IUnipilotFactory(0x95b77505B38F8A261adA04f54B8D0cdA08904708);

        nfp = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
        vm.label(nfp, "NonFungiblePM");

        swap = new SwapExamples(
            ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564)
        );
        vm.label(address(swap), "Swap Router");

        token0 = new MyERC20("token0", address(this));
        token1 = new MyERC20("token1", address(this));
        t0 = address(token0);
        t1 = address(token1);
        vm.label(t0, "T0");
        vm.label(t1, "T1");

        liquidityAfterDeposits = new uint128[](20);
        liquidityAfterDepositsOnUnipilot = new uint256[](20);
    }

    function createUsers() private {
        depositors = new address[](10);
        depositorsOnUnipilot = new address[](10);
        swappers = new address[](10);

        for (uint256 i = 0; i < 10; i++) {
            depositors[i] = vm.addr(100 + i);
            swappers[i] = vm.addr(200 + i);
            depositorsOnUnipilot[i] = vm.addr(300 + i);

            startHoax(depositors[i]);

            IERC20(t0).approve(nfp, type(uint256).max);
            IERC20(t1).approve(nfp, type(uint256).max);
            IERC20(t0).approve(activeVault, type(uint256).max);
            IERC20(t1).approve(activeVault, type(uint256).max);
            IERC20(t0).approve(address(swap), type(uint256).max);
            IERC20(t1).approve(address(swap), type(uint256).max);

            vm.stopPrank();

            startHoax(swappers[i]);

            IERC20(t0).approve(nfp, type(uint256).max);
            IERC20(t1).approve(nfp, type(uint256).max);
            IERC20(t0).approve(activeVault, type(uint256).max);
            IERC20(t1).approve(activeVault, type(uint256).max);
            IERC20(t0).approve(address(swap), type(uint256).max);
            IERC20(t1).approve(address(swap), type(uint256).max);

            vm.stopPrank();

            startHoax(depositorsOnUnipilot[i]);

            IERC20(t0).approve(nfp, type(uint256).max);
            IERC20(t1).approve(nfp, type(uint256).max);
            IERC20(t0).approve(activeVault, type(uint256).max);
            IERC20(t1).approve(activeVault, type(uint256).max);
            IERC20(t0).approve(address(swap), type(uint256).max);
            IERC20(t1).approve(address(swap), type(uint256).max);

            vm.stopPrank();

            token0._mint(depositors[i], 100 ether);
            token1._mint(depositors[i], 100 ether);
            token0._mint(swappers[i], 10000 ether);
            token1._mint(swappers[i], 10000 ether);
            token0._mint(depositorsOnUnipilot[i], 100 ether);
            token1._mint(depositorsOnUnipilot[i], 100 ether);
        }
    }

    function calculateSqrtPrice(
        uint256 amount0,
        uint256 amount1
    ) public pure returns (uint256) {
        uint256 sqrtPrice = (amount0.div(amount1).sqrt().mul(2 ** 96).div(3));
        return sqrtPrice;
    }

    function getMinTick(int24 tickSpacing) public pure returns (int24) {
        return (-22974 / tickSpacing + 1) * tickSpacing;
    }

    function getMaxTick(int24 tickSpacing) public pure returns (int24) {
        return (22974 / tickSpacing) * tickSpacing;
    }

    function setupUnipilotVault() private {
        //setUp
        uint256 _sqrtPriceX96 = calculateSqrtPrice(1, 1);

        startHoax(_governance);
        activeVault = activeFactory.createVault(
            t0,
            t1,
            uint24(500),
            uint16(0),
            uint160(_sqrtPriceX96),
            "Vault1Poly",
            "UV1P"
        );
        pool = _algebraFactory.getPool(t0, t1,uint24(500));
        vm.label(pool, "UniswapV3Pool");

        address[] memory pools = new address[](1);
        uint16[] memory sTypes = new uint16[](1);
        int24[] memory bMults = new int24[](1);
        pools[0] = pool;
        sTypes[0] = 0;
        bMults[0] = 100;

        UnipilotStrategy(_uniStrategy).setBaseTicks(pools, sTypes, bMults);
        UnipilotStrategy(_uniStrategy).setMaxTwapDeviation(int24(9000));

        UnipilotActiveVault(payable(activeVault)).toggleOperator(_governance);

        UnipilotActiveVault(payable(activeVault)).rebalance(
            int256(0),
            false,
            -int24(getMinTick(60)),
            int24(getMaxTick(60))
        );
        vm.stopPrank();

        createUsers();
    }

    function swapNigga(
        uint256 loop,
        address tokenin,
        address tokenout
    ) private returns (uint256 amountout) {
        for (uint256 i = 0; i < loop; i++) {
            uint256 amountin = 10 ether;
            startHoax(swappers[i]);
            amountout = swap.swapExactInputSingle(amountin, tokenin, tokenout);
            vm.stopPrank();
            vm.roll(block.number + 10);
        }
    }

    using Strings for uint256;

    function division(
        uint256 decimalPlaces,
        uint256 numerator,
        uint256 denominator
    )
        public
        pure
        returns (uint256 quotient, uint256 remainder, string memory result)
    {
        uint256 factor = 10 ** decimalPlaces;
        quotient = numerator / denominator;
        bool rounding = 2 * ((numerator * factor) % denominator) >= denominator;
        remainder = ((numerator * factor) / denominator) % factor;
        if (rounding) {
            remainder += 1;
        }
        result = string(
            abi.encodePacked(
                quotient.toString(),
                ".",
                numToFixedLengthStr(decimalPlaces, remainder)
            )
        );
    }

    function numToFixedLengthStr(
        uint256 decimalPlaces,
        uint256 num
    ) internal pure returns (string memory result) {
        bytes memory byteString;
        for (uint256 i = 0; i < decimalPlaces; i++) {
            uint256 remainder = num % 10;
            byteString = abi.encodePacked(remainder.toString(), byteString);
            num = num / 10;
        }
        result = string(byteString);
    }

    function createTwoUsers() private {
        // ===========================================================

        vm.label(user1, "User1");

        startHoax(user1);
        IERC20(t0).approve(nfp, type(uint256).max);
        IERC20(t1).approve(nfp, type(uint256).max);
        IERC20(t0).approve(activeVault, type(uint256).max);
        IERC20(t1).approve(activeVault, type(uint256).max);
        IERC20(t0).approve(address(swap), type(uint256).max);
        IERC20(t1).approve(address(swap), type(uint256).max);

        token0._mint(user1, 1000 ether);
        token1._mint(user1, 1000 ether);
        vm.stopPrank();

        // ===========================================================

        vm.label(user2, "User2");

        startHoax(user2);
        IERC20(t0).approve(nfp, type(uint256).max);
        IERC20(t1).approve(nfp, type(uint256).max);
        IERC20(t0).approve(activeVault, type(uint256).max);
        IERC20(t1).approve(activeVault, type(uint256).max);
        IERC20(t0).approve(address(swap), type(uint256).max);
        IERC20(t1).approve(address(swap), type(uint256).max);

        token0._mint(user2, 1000 ether);
        token1._mint(user2, 1000 ether);
        vm.stopPrank();

        // ===========================================================

        startHoax(user3);
        IERC20(t0).approve(nfp, type(uint256).max);
        IERC20(t1).approve(nfp, type(uint256).max);
        IERC20(t0).approve(activeVault, type(uint256).max);
        IERC20(t1).approve(activeVault, type(uint256).max);
        IERC20(t0).approve(address(swap), type(uint256).max);
        IERC20(t1).approve(address(swap), type(uint256).max);

        token0._mint(user3, 100 ether);
        token1._mint(user3, 100 ether);
        vm.stopPrank();
    }

    function testFeeDistributions() public {
        //setUp
        console.log("======== Setting Up Unipilot ========");
        setupUnipilotVault();
        console.log("======== Creating Users to interact ========");
        createTwoUsers();
        vm.roll(block.number + 10);

        // ===========================================================
        console.log("\nUser's Flow:\n");
        //execution
        hoax(user1);
        (uint256 lq1, uint256 a01, uint256 a11) = IUnipilotVault(activeVault)
            .deposit(500 ether, 500 ether, user1);
        vm.roll(block.number + 10);

        console.log("======== First Deposit Completed ========");

        swapNigga(10, t0, t1);
        swapNigga(2, t1, t0);

        swapNigga(10, t0, t1);
        swapNigga(2, t1, t0);
        
        swapNigga(10, t0, t1);
        swapNigga(2, t1, t0);

        swapNigga(10, t0, t1);
        swapNigga(2, t1, t0);

        console.log("======== Multiple Swaps Completed ========");

        vm.roll(block.number + 10);
        hoax(user2);
        (uint256 lq2, uint256 a02, uint256 a12) = IUnipilotVault(activeVault)
            .deposit(500015e15, 501021e15, user2);

        console.log("======== Second Deposit Completed ========");

        hoax(_governance);
        UnipilotActiveVault(payable(activeVault)).rebalance(
            int256(0),
            false,
            -int24(getMinTick(60)),
            int24(getMaxTick(60))
        );
        vm.roll(block.number + 10);

        console.log("======== Rebalance Completed ========");

        hoax(user2);
        (uint256 a0u2aw, uint256 a1u2aw) = IUnipilotVault(activeVault).withdraw(
            lq2,
            user2,
            false
        );
        vm.roll(block.number + 10);

        console.log("======== Second User Withdrawn ========");

        hoax(user1);
        (uint256 a0u1aw, uint256 a1u1aw) = IUnipilotVault(activeVault).withdraw(
            lq1,
            user1,
            false
        );

        console.log("======== First User Withdrawn ========");

        (, , string memory newLQ1) = division(7, lq1, 1e17);
        (, , string memory newLQ2) = division(7, lq2, 1e17);
        (, , string memory newA01) = division(7, a01, 1e17);
        (, , string memory newA11) = division(7, a11, 1e17);
        (, , string memory newA02) = division(7, a02, 1e17);
        (, , string memory newA12) = division(7, a12, 1e17);
        (, , string memory newA011) = division(17, a0u1aw, 1e17);
        (, , string memory newA111) = division(17, a1u1aw, 1e17);
        (, , string memory newA012) = division(17, a0u2aw, 1e17);
        (, , string memory newA112) = division(17, a1u2aw, 1e17);

        console.log("\nDetailed Figures:\n");

        console.log("Amounts Deposited:");

        console.log("User 1 Token 0: \t", newA01);
        console.log("User 1 Token 1: \t", newA11);
        console.log("User 2 Token 0: \t", newA02);
        console.log("User 2 Token 1: \t", newA12);

        console.log("\nLiquidity Recieved:");

        console.log("User 1 Vault LP: \t", newLQ1);
        console.log("User 2 Vault LP: \t", newLQ2);

        console.log("\nWithdrawn for 5000.00.. LP Tokens each:");
        console.log("User 1 T0: \t", newA011);
        console.log("User 1 T1: \t", newA111);
        console.log("User 2 T0: \t", newA012);
        console.log("User 2 T1: \t", newA112);

        //assert
        // require(lq1 == lq2, "Wrong liquidities");
    }
    // function testFeeDistribution() public {
    //     //setUp
    //     console.log("======== Setting Up Unipilot ========");
    //     setupUnipilotVault();
    //     console.log("======== Creating Users to interact ========");
    //     createTwoUsers();
    //     vm.roll(block.number + 10);

    //     // ===========================================================
    //     console.log("\nUser's Flow:\n");
    //     //execution
    //     hoax(user1);
    //     (uint256 lq1, uint256 a01, uint256 a11) = IUnipilotVault(activeVault)
    //         .deposit(500 ether, 500 ether, user1);
    //     vm.roll(block.number + 10);

    //     console.log("======== First Deposit Completed ========");

    //     swapNigga(10, t0, t1);
    //     swapNigga(2, t1, t0);

    //     console.log("======== Swaps Completed ========");

    //     vm.roll(block.number + 10);
    //     hoax(user2);
    //     (uint256 lq2, uint256 a02, uint256 a12) = IUnipilotVault(activeVault)
    //         .deposit(501 ether, 501 ether, user2);

    //     console.log("======== Second Deposit Completed ========");

    //     hoax(_governance);
    //     UnipilotActiveVault(payable(activeVault)).rebalance(
    //         int256(0),
    //         false,
    //         -int24(getMinTick(60)),
    //         int24(getMaxTick(60))
    //     );
    //     vm.roll(block.number + 10);

    //     console.log("======== Rebalance Completed ========");

    //     // swapNigga(5, t1, t0);
    //     // console.log("======== Second Swap Completed Completed ========");

    //     hoax(user2);
    //     (uint256 a012, uint256 a112) = IUnipilotVault(activeVault).withdraw(
    //         lq1,
    //         user2,
    //         false
    //     );
    //     vm.roll(block.number + 10);

    //     console.log("======== Second User Withdrawn ========");

    //     hoax(user1);
    //     (uint256 a011, uint256 a111) = IUnipilotVault(activeVault).withdraw(
    //         lq1,
    //         user1,
    //         false
    //     );

    //     console.log("======== First User Withdrawn ========");

    //     (,,string memory newLQ1) = division(7, lq1, 1e17);
    //     (,,string memory newLQ2) = division(7, lq2, 1e17);
    //     (,,string memory newA01) = division(7, a01, 1e17);
    //     (,,string memory newA11) = division(7, a11, 1e17);
    //     (,,string memory newA02) = division(7, a02, 1e17);
    //     (,,string memory newA12) = division(7, a12, 1e17);
    //     (,,string memory newA011) = division(7, a011, 1e17);
    //     (,,string memory newA012) = division(7, a012, 1e17);
    //     (,,string memory newA111) = division(7, a111, 1e17);
    //     (,,string memory newA112) = division(7, a112, 1e17);

    //     console.log("\nDetailed Figures:\n");
    //     console.log("User 1 Token 0: \t", newA01);
    //     console.log("User 1 Token 1: \t", newA11);

    //     console.log("===Swaps performed===\n");

    //     console.log("User 2 Token 0: \t", newA02);
    //     console.log("User 2 Token 1: \t", newA12);

    //     console.log("\nLiquidity Recieved:");

    //     console.log("User 1 Vault LP: \t", newLQ1);
    //     console.log("User 2 Vault LP: \t", newLQ2);

    //     console.log("\nAmounts Withdrawn against common LP amount 5000.0000000:");
    //     console.log("User 1 Token 0: \t", newA011);
    //     console.log("User 1 Token 1: \t", newA012);
    //     console.log("User 2 Token 0: \t", newA111);
    //     console.log("User 2 Token 1: \t", newA112);

    //     //assert
    //     // require(lq1 == lq2, "Wrong liquidities");
    // }
}

contract SwapExamples {
    ISwapRouter public immutable swapRouter;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    function swapExactInputSingle(
        uint256 amountIn,
        address _tokenIn,
        address _tokenOut
    ) external returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(
            _tokenIn,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(_tokenIn, address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: uint24(500),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }
}
