// //SPDX-License-Identifier: MIT
// pragma solidity ^0.7.6;
// pragma abicoder v2;

// import "../dependencies/UniswapV3Factory.sol";
// import "../UnipilotStrategy.sol";
// import "../dependencies/WETH.sol";
// import { UnipilotActiveFactory } from "../UnipilotActiveFactory.sol";
// import { UnipilotActiveVault, IERC20 } from "../UnipilotActiveVault.sol";

// contract indexfund {
//     mapping(address => uint256) private balance0;
//     mapping(address => uint256) private balance1;

//     function balance(address tokenAddress) public view returns (uint256 bal) {
//         bal = IERC20(tokenAddress).balanceOf(address(this));
//     }
// }

// contract token {
//     // --- Auth ---
//     constructor(address _sender) {
//         _mint(_sender, 1e18 ether);
//     }

//     // --- ERC20 Data ---
//     string public constant name = "Dai Stablecoin";
//     string public constant symbol = "DAI";
//     string public constant version = "2";
//     uint8 public constant decimals = 18;
//     uint256 public totalSupply;

//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;
//     mapping(address => uint256) public nonces;

//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Rely(address indexed usr);
//     event Deny(address indexed usr);

//     // --- Math ---
//     function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
//         require((z = x + y) >= x);
//     }

//     function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
//         require((z = x - y) <= x);
//     }

//     // --- ERC20 Mutations ---
//     function transfer(address to, uint256 value) external returns (bool) {
//         require(to != address(0) && to != address(this), "Dai/invalid-address");
//         uint256 balance = balanceOf[msg.sender];
//         require(balance >= value, "Dai/insufficient-balance");

//         balanceOf[msg.sender] = balance - value;
//         balanceOf[to] += value;

//         emit Transfer(msg.sender, to, value);

//         return true;
//     }

//     function transferFrom(
//         address from,
//         address to,
//         uint256 value
//     ) external returns (bool) {
//         require(to != address(0) && to != address(this), "Dai/invalid-address");
//         uint256 balance = balanceOf[from];
//         require(balance >= value, "Dai/insufficient-balance");

//         // if (from != msg.sender) {
//         //   uint256 allowed = allowance[from][msg.sender];
//         //   if (allowed != type(uint256).max) {
//         //     require(allowed >= value, "Dai/insufficient-allowance");

//         //     allowance[from][msg.sender] = allowed - value;
//         //   }
//         // }

//         balanceOf[from] = balance - value;
//         balanceOf[to] += value;

//         emit Transfer(from, to, value);

//         return true;
//     }

//     // --- Mint/Burn ---

//     function _mint(address to, uint256 value) private {
//         require(to != address(0) && to != address(this), "Dai/invalid-address");
//         balanceOf[to] = balanceOf[to] + value; // note: we don't need an overflow check here b/c balanceOf[to] <= totalSupply and there is an overflow check below
//         totalSupply = _add(totalSupply, value);

//         emit Transfer(address(0), to, value);
//     }

//     function burn(address from, uint256 value) external {
//         uint256 balance = balanceOf[from];
//         require(balance >= value, "Dai/insufficient-balance");

//         // if (from != msg.sender && wards[msg.sender] != 1) {
//         //   uint256 allowed = allowance[from][msg.sender];
//         //   if (allowed != type(uint256).max) {
//         //     require(allowed >= value, "Dai/insufficient-allowance");

//         //     allowance[from][msg.sender] = allowed - value;
//         //   }
//         // }

//         balanceOf[from] = balance - value; // note: we don't need overflow checks b/c require(balance >= value) and balance <= totalSupply
//         totalSupply = totalSupply - value;

//         emit Transfer(from, address(0), value);
//     }
// }

// contract testUnipiot {
//     UniswapV3Factory private factory;
//     UnipilotActiveFactory private UAF;
//     UnipilotStrategy private ST;
//     indexfund private IF;
//     WETH9 private weth;
//     UnipilotActiveVault private UAV;
//     token private tk1;
//     token private tk2;
//     address public t0;
//     address public t1;
//     address private admin = msg.sender;

//     constructor(uint256 amount0, uint256 amount1, uint16 vaultStrategy) {
//         factory = new UniswapV3Factory();
//         ST = new UnipilotStrategy(address(this));
//         IF = new indexfund();
//         weth = new WETH9();
//         UAF = new UnipilotActiveFactory(
//             address(factory),
//             admin,
//             address(ST),
//             address(IF),
//             address(weth),
//             1
//         );
//        // testInit(amount0, amount1, vaultStrategy);
//     }

//     function createToken(
//         address sender
//     ) private returns (address tok0, address tok1) {
//         tk1 = new token(sender);
//         tk2 = new token(sender);
//         tok1 = address(tk1);
//         tok0 = address(tk2);
//     }

//     function FeeTier() private view returns (uint24) {
//         uint24 LOW = 500; // 0.05% fee tier
//         uint24 MEDIUM = 3000; // 0.30% fee tier
//         uint24 HIGH = 10000; // 1.00% fee tier

//         uint256 rand = uint256(
//             keccak256(
//                 abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
//             )
//         ) % 3;

//         if (rand == 0) {
//             return LOW;
//         } else if (rand == 1) {
//             return MEDIUM;
//         } else {
//             return HIGH;
//         }
//     }

//     function gettokens() private {
//         (t0, t1) = createToken(msg.sender);
//     }

//     function encodePriceSqrt(
//         uint256 reserve1,
//         uint256 reserve0
//     ) private pure returns (uint160 encodedPriceSqrt) {
//         require(reserve1 != 0 && reserve0 != 0, "ZERO");
//         uint256 prod = reserve1 * 1e18;
//         uint256 priceSqrt = 0;
//         uint256 num = prod / reserve0;
//         uint256 min = 0;
//         uint256 max = (num + 1) / 2;
//         while (min <= max) {
//             uint256 mid = (min + max) / 2;
//             if ((mid * mid) <= num) {
//                 priceSqrt = mid;
//                 min = mid + 1;
//             } else {
//                 max = mid - 1;
//             }
//         }
//         encodedPriceSqrt = uint160(priceSqrt << 96) / 1e9;
//     }

//     event here(string);
//     event fee(uint24);
//     event Sqrt(uint160);

//     //Createting UnipilotActiveVault using UnipilotActiveFactory
//     //Arbitary (valid in range) values been sent by echidna to fuzz different scenarios
//     function testInit(
//         uint256 _amount0,
//         uint256 _amount1,
//         uint16 _vaultStrategy
//     ) public {
//         gettokens();
//         uint160 _sqrtPriceX96 = encodePriceSqrt(_amount0, _amount1);
//         uint24 fees = FeeTier();

//         require(_vaultStrategy < 5, "VS");
//         emit Sqrt(_sqrtPriceX96);
//         emit fee(fees);

//         address vault = UAF.createVault(
//             address(t0),
//             address(t1),
//             uint24(3000),
//             _vaultStrategy,
//             uint160(79228162514264337593543950336),
//             "Fuzz",
//             "fuzz"
//         );

//         // assert(vault != address(0));
//         // UAV = UnipilotActiveVault(payable(vault));

//         // address pool = factory.getPool(t0, t1, fees);
//         // address[] memory pools = new address[](1);
//         // uint16[] memory sTypes = new uint16[](1);
//         // int24[] memory bMults = new int24[](1);
//         // pools[0] = pool;
//         // sTypes[0] = _vaultStrategy;
//         // bMults[0] = 100;
//         // emit here("here");
//         // ST.setBaseTicks(pools, sTypes, bMults);
//         // //ST.setMaxTwapDeviation(int24(9000));

//         // UAV.toggleOperator(msg.sender);
//     }

//     function DoDeposit(uint256 amount0, uint256 amount1) public payable {
//         uint256 bal = IERC20(t0).balanceOf(msg.sender);
//         require(bal > 0, "IB");
//         UAV.deposit(amount0, amount1, msg.sender);
//     }

//     function DoWithdraw(uint256 liquidity, bool refundAsETH) private {
//         UAV.withdraw(liquidity, msg.sender, refundAsETH);
//     }

//     function DoRebelance(uint8 swapBP) private {
//         UAV.readjustLiquidity(swapBP);
//     }
// }


//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../dependencies/UniswapV3Factory.sol";
import "../UnipilotStrategy.sol";
import "../dependencies/WETH.sol";
// import { UnipilotActiveFactory as uniFac } from "../UnipilotActiveFactory.sol";
import { UnipilotActiveFactory } from "../UnipilotActiveFactory.sol";


contract indexfund {
    mapping(address => uint256) private balance0;
    mapping(address => uint256) private balance1;
}

contract token {

    // --- ERC20 Data ---
    string public constant name = "Dai Stablecoin";
    string public constant symbol = "DAI";
    string public constant version = "2";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    // --- Math ---
    function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }


    constructor(address _sender) {
        _mint(_sender, 100 ether);
    }

  
    // --- ERC20 Mutations ---
    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "Dai/invalid-address");
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "Dai/insufficient-balance");

        balanceOf[msg.sender] = balance - value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        require(to != address(0) && to != address(this), "Dai/invalid-address");
        uint256 balance = balanceOf[from];
        require(balance >= value, "Dai/insufficient-balance");

        // if (from != msg.sender) {
        //   uint256 allowed = allowance[from][msg.sender];
        //   if (allowed != type(uint256).max) {
        //     require(allowed >= value, "Dai/insufficient-allowance");

        //     allowance[from][msg.sender] = allowed - value;
        //   }
        // }

        balanceOf[from] = balance - value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);

        return true;
    }

      function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
      }
      function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 newValue = _add(allowance[msg.sender][spender], addedValue);
        allowance[msg.sender][spender] = newValue;

        emit Approval(msg.sender, spender, newValue);

        return true;
      }
      function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 allowed = allowance[msg.sender][spender];
        require(allowed >= subtractedValue, "Dai/insufficient-allowance");
        allowed = allowed - subtractedValue;
        allowance[msg.sender][spender] = allowed;

        emit Approval(msg.sender, spender, allowed);

        return true;
      }

    // --- Mint/Burn ---

    function _mint(address to, uint256 value) public {
        require(to != address(0) && to != address(this), "Dai/invalid-address");
        balanceOf[to] = balanceOf[to] + value; // note: we don't need an overflow check here b/c balanceOf[to] <= totalSupply and there is an overflow check below
        totalSupply = _add(totalSupply, value);

        emit Transfer(address(0), to, value);
    }

    function burn(address from, uint256 value) external {
        uint256 balance = balanceOf[from];
        require(balance >= value, "Dai/insufficient-balance");

        // if (from != msg.sender && wards[msg.sender] != 1) {
        //   uint256 allowed = allowance[from][msg.sender];
        //   if (allowed != type(uint256).max) {
        //     require(allowed >= value, "Dai/insufficient-allowance");

        //     allowance[from][msg.sender] = allowed - value;
        //   }
        // }

        balanceOf[from] = balance - value; // note: we don't need overflow checks b/c require(balance >= value) and balance <= totalSupply
        totalSupply = totalSupply - value;

        emit Transfer(from, address(0), value);
    }

  
}

contract testUnipiot {
    UniswapV3Factory factory;
    UnipilotActiveFactory public UAF;
    UnipilotStrategy ST;
    indexfund IF;
    WETH9 weth;
    token internal tk0;
    token internal tk1;

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

    function createToken(address sender) internal returns(address t0, address t1){
        tk1 = new token(sender);
        tk0 = new token(sender);
        t1 = address(tk1);
        t0 = address(tk0);
    }
}
