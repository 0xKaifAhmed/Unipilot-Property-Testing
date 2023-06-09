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

    event fee(uint24);
    event Sqrt(uint160);

    //Createting UnipilotActiveVault using UnipilotActiveFactory
    //Arbitary (valid in range) values been sent by echidna to fuzz different scenarios
    function Init(
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
        ST.setBaseTicks(pools, sTypes, bMults);
        ST.setMaxTwapDeviation(int24(9000));
        UAV.toggleOperator(msg.sender);
        
    }
    
    function getCurrentTick() public view returns(int24 tick) {
        ( , tick , , , , , ) = IUniswapV3Pool(pool).slot0();
    }

}
