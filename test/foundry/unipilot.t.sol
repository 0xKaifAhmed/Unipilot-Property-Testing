//SPDX-License-Identifier:MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../contracts/foundry/testSetup.sol";
import "../../contracts/foundry/Token.sol";

contract Fuzz is Test {
    UnipilotFuzz fuzz;
    Token token0;
    Token token1;

    function setUp() public {
        token0 = new Token(address(this));
        token1 = new Token(address(this));
        fuzz = new UnipilotFuzz();
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
        mintTokens();
        invariant_checkLpSupplyBeforeAndAfterWithdraw(amount0, amount1);
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

    // function invariant_MintedLpAreSameAsUnipilot() public {
    //     //todo
    //     //calculate LP shares of amount getting deposite according to previous deposits
    //     //then actually deposit that amount an check if you get the same amount
    //     //if yes invariants holds
    //     //if no you made a mistake :p
    // }
    
}
