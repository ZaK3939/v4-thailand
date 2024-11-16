// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
// import {Hooks} from "v4-core/src/libraries/Hooks.sol";
// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
// import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

// contract MinimalMarketHook is BaseHook {
//     using PoolIdLibrary for PoolKey;

//     struct PoolState {
//         uint256 lastTradeTime;
//         uint256 accumulatedVolume;
//         uint24 currentFee;
//     }

//     mapping(PoolId => PoolState) public poolStates;
//     mapping(PoolId => uint256) public baseRates;

//     event FeeUpdated(PoolId indexed poolId, uint24 newFee);

//     constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

//     function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
//         return Hooks.Permissions({
//             beforeInitialize: false,
//             afterInitialize: false,
//             beforeAddLiquidity: false,
//             afterAddLiquidity: false,
//             beforeRemoveLiquidity: false,
//             afterRemoveLiquidity: false,
//             beforeSwap: true,
//             afterSwap: false,
//             beforeDonate: false,
//             afterDonate: false,
//             beforeSwapReturnDelta: true,
//             afterSwapReturnDelta: false,
//             afterAddLiquidityReturnDelta: false,
//             afterRemoveLiquidityReturnDelta: false
//         });
//     }

//     function beforeSwap(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         bytes calldata
//     ) external override returns (bytes4, BeforeSwapDelta, uint24) {
//         PoolId poolId = key.toId();
//         PoolState storage state = poolStates[poolId];

//         uint24 fee = _calculateDynamicFee(state, uint256(params.amountSpecified));
//         state.currentFee = fee;
//         state.lastTradeTime = block.timestamp;
        
//         emit FeeUpdated(poolId, fee);

//         return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee);
//     }

//     function _calculateDynamicFee(PoolState storage state, uint256 amount) internal view returns (uint24) {
//         // 時間間隔に基づくフィー調整
//         uint256 timeDelta = block.timestamp - state.lastTradeTime;
//         if (timeDelta < 1 minutes) {
//             return state.currentFee + 100; // +1%
//         }
//         return state.currentFee;
//     }
// }