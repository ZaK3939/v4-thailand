// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GachaPoolHook is BaseHook {
   using CurrencySettler for Currency;

    error AddLiquidityThroughHook();
    
    struct CallbackData {
    uint256 amountEach; // Amount of each token to add as liquidity
    Currency currency0;
    Currency currency1;
    address sender;
}

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert AddLiquidityThroughHook();
    }

    function addLiquidity(PoolKey calldata key, uint256 amountEach) external {
        poolManager.unlock(
            abi.encode(
                CallbackData(
                    amountEach,
                    key.currency0,
                    key.currency1,
                    msg.sender
                )
            )
        );
    }


    function _unlockCallback(
        bytes calldata data
    ) internal override returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        // Settle `amountEach` of each currency from the sender
        // i.e. Create a debit of `amountEach` of each currency with the Pool Manager
        callbackData.currency0.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false // `burn` = `false` i.e. we're actually transferring tokens, not burning ERC-6909 Claim Tokens
        );
        callbackData.currency1.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false
        );

        // Since we didn't go through the regular "modify liquidity" flow,
        // the PM just has a debit of `amountEach` of each currency from us
        // We can, in exchange, get back ERC-6909 claim tokens for `amountEach` of each currency
        // to create a credit of `amountEach` of each currency to us
        // that balances out the debit

        // We will store those claim tokens with the hook, so when swaps take place
        // liquidity from our CSMM can be used by minting/burning claim tokens the hook owns
        callbackData.currency0.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true // true = mint claim tokens for the hook, equivalent to money we just deposited to the PM
        );
        callbackData.currency1.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true
        );

        return "";
    }

    function beforeSwap(
    address,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    bytes calldata
) external override returns (bytes4, BeforeSwapDelta, uint24) {
    uint256 amountInOutPositive = params.amountSpecified > 0
        ? uint256(params.amountSpecified)
        : uint256(-params.amountSpecified);

    /**
        BalanceDelta is a packed value of (currency0Amount, currency1Amount)

        BeforeSwapDelta varies such that it is not sorted by token0 and token1
        Instead, it is sorted by "specifiedCurrency" and "unspecifiedCurrency"

        Specified Currency => The currency in which the user is specifying the amount they're swapping for
        Unspecified Currency => The other currency

        For example, in an ETH/USDC pool, there are 4 possible swap cases:

        1. ETH for USDC with Exact Input for Output (amountSpecified = negative value representing ETH)
        2. ETH for USDC with Exact Output for Input (amountSpecified = positive value representing USDC)
        3. USDC for ETH with Exact Input for Output (amountSpecified = negative value representing USDC)
        4. USDC for ETH with Exact Output for Input (amountSpecified = positive value representing ETH)

        In Case (1):
            -> the user is specifying their swap amount in terms of ETH, so the specifiedCurrency is ETH
            -> the unspecifiedCurrency is USDC

        In Case (2):
            -> the user is specifying their swap amount in terms of USDC, so the specifiedCurrency is USDC
            -> the unspecifiedCurrency is ETH

        In Case (3):
            -> the user is specifying their swap amount in terms of USDC, so the specifiedCurrency is USDC
            -> the unspecifiedCurrency is ETH

        In Case (4):
            -> the user is specifying their swap amount in terms of ETH, so the specifiedCurrency is ETH
            -> the unspecifiedCurrency is USDC
    
        -------
        
        Assume zeroForOne = true (without loss of generality)
        Assume abs(amountSpecified) = 100

        For an exact input swap where amountSpecified is negative (-100)
            -> specified token = token0
            -> unspecified token = token1
            -> we set deltaSpecified = -(-100) = 100
            -> we set deltaUnspecified = -100
            -> i.e. hook is owed 100 specified token (token0) by PM (that comes from the user)
            -> and hook owes 100 unspecified token (token1) to PM (to go to the user)
    
        For an exact output swap where amountSpecified is positive (100)
            -> specified token = token1
            -> unspecified token = token0
            -> we set deltaSpecified = -100
            -> we set deltaUnspecified = 100
            -> i.e. hook owes 100 specified token (token1) to PM (to go to the user)
            -> and hook is owed 100 unspecified token (token0) by PM (that comes from the user)

        In either case, we can design BeforeSwapDelta as (-params.amountSpecified, params.amountSpecified)
    
    */

    BeforeSwapDelta beforeSwapDelta = toBeforeSwapDelta(
        int128(-params.amountSpecified), // So `specifiedAmount` = +100
        int128(params.amountSpecified) // Unspecified amount (output delta) = -100
    );

    if (params.zeroForOne) {
        // If user is selling Token 0 and buying Token 1

        // They will be sending Token 0 to the PM, creating a debit of Token 0 in the PM
        // We will take claim tokens for that Token 0 from the PM and keep it in the hook to create an equivalent credit for ourselves
        key.currency0.take(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );

        // They will be receiving Token 1 from the PM, creating a credit of Token 1 in the PM
        // We will burn claim tokens for Token 1 from the hook so PM can pay the user
        key.currency1.settle(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );
    } else {
        key.currency0.settle(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );
        key.currency1.take(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );
    }

    return (this.beforeSwap.selector, beforeSwapDelta, 0);
}
}