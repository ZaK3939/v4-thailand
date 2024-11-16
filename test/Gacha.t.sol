// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {GachaPoolHook} from "../src/GachaPoolHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract GachaPoolHookTest is Test, Deployers, Fixtures  {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    GachaPoolHook hook;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );

        // Deploy the hook implementation
        bytes memory constructorArgs = abi.encode(manager);
        deployCodeTo("GachaPoolHook.sol:GachaPoolHook", constructorArgs, hookAddress);
        hook = GachaPoolHook(hookAddress);

        // Create the pool
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        manager.initialize(key, SQRT_PRICE_1_1);

        // Mint tokens to this contract for testing
        uint256 amount = 1000e18;
        
        // Mint tokens to this contract
        deal(Currency.unwrap(currency0), address(this), amount * 2);
        deal(Currency.unwrap(currency1), address(this), amount * 2);

        // Approve tokens for the hook
        IERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);

        // Add initial liquidity through the hook
        hook.addLiquidity(key, amount);
    }

    function test_cannotModifyLiquidity() public {
 
        vm.expectRevert();
        
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1e18,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_claimTokenBalances() public view {
        uint256 token0ClaimID = CurrencyLibrary.toId(currency0);
        uint256 token1ClaimID = CurrencyLibrary.toId(currency1);

        uint256 token0ClaimsBalance = manager.balanceOf(
            address(hook),
            token0ClaimID
        );
        uint256 token1ClaimsBalance = manager.balanceOf(
            address(hook),
            token1ClaimID
        );

        assertEq(token0ClaimsBalance, 1000e18);
        assertEq(token1ClaimsBalance, 1000e18);
    }

    function test_swap_exactInput_zeroForOne() public {
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Get initial balances
        uint256 balanceOfTokenABefore = key.currency0.balanceOfSelf();
        uint256 balanceOfTokenBBefore = key.currency1.balanceOfSelf();

        // Perform swap
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );

        // Get final balances
        uint256 balanceOfTokenAAfter = key.currency0.balanceOfSelf();
        uint256 balanceOfTokenBAfter = key.currency1.balanceOfSelf();

        // Verify 1:1 exchange
        assertEq(balanceOfTokenBAfter - balanceOfTokenBBefore, 100e18);
        assertEq(balanceOfTokenABefore - balanceOfTokenAAfter, 100e18);
    }

    function test_swap_exactOutput_zeroForOne() public {
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Get initial balances
        uint256 balanceOfTokenABefore = key.currency0.balanceOfSelf();
        uint256 balanceOfTokenBBefore = key.currency1.balanceOfSelf();

        // Perform swap
        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );

        // Get final balances
        uint256 balanceOfTokenAAfter = key.currency0.balanceOfSelf();
        uint256 balanceOfTokenBAfter = key.currency1.balanceOfSelf();

        // Verify 1:1 exchange
        assertEq(balanceOfTokenBAfter - balanceOfTokenBBefore, 100e18);
        assertEq(balanceOfTokenABefore - balanceOfTokenAAfter, 100e18);
    }
}