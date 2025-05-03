// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IShariaWhitelist} from "./interfaces/IShariaWhitelist.sol";

/**
 * @title ShariaHook
 * @dev A Uniswap v4 hook that enforces Sharia compliance by checking if tokens are whitelisted
 */
contract ShariaHook is BaseHook {
    // Use CurrencyLibrary for Currency type
    using CurrencyLibrary for Currency;

    // Reference to the whitelist contract
    IShariaWhitelist public immutable whitelistContract;

    /**
     * @dev Constructor initializes the hook with the pool manager and whitelist contract
     * @param _manager The Uniswap v4 pool manager
     * @param _whitelistContract The address of the Sharia whitelist contract
     */
    constructor(IPoolManager _manager, address _whitelistContract) BaseHook(_manager) {
        require(_whitelistContract != address(0), "Invalid whitelist contract address");
        whitelistContract = IShariaWhitelist(_whitelistContract);
    }

    /**
     * @dev Set up hook permissions
     * @return Hooks.Permissions The permissions for this hook
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * @dev Checks if tokens are Sharia-compliant before allowing liquidity addition
     * @param key The pool key containing token information
     * @return bytes4 Function selector
     */
    function _beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal override returns (bytes4) {
        // Check if both tokens in the pair are whitelisted
        _checkTokenCompliance(key);
        return BaseHook.beforeAddLiquidity.selector;
    }

    /**
     * @dev Checks if tokens are Sharia-compliant before allowing swaps
     * @param key The pool key containing token information
     * @return bytes4 Function selector
     * @return BeforeSwapDelta No delta changes
     * @return uint24 No fee changes
     */
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Check if both tokens in the pair are whitelisted
        _checkTokenCompliance(key);
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @dev Helper function to check if both tokens in a pair are Sharia-compliant
     * @param key The pool key containing token information
     */
    function _checkTokenCompliance(PoolKey calldata key) internal view {
        // Get token addresses from Currency objects
        address token0 = key.currency0.isAddressZero() ? address(0) : Currency.unwrap(key.currency0);
        address token1 = key.currency1.isAddressZero() ? address(0) : Currency.unwrap(key.currency1);

        // Native ETH (address(0)) is always considered compliant
        bool token0Compliant = token0 == address(0) ? true : whitelistContract.isTokenWhitelisted(token0);
        bool token1Compliant = token1 == address(0) ? true : whitelistContract.isTokenWhitelisted(token1);

        // Revert if either token is not whitelisted
        require(token0Compliant, "Token0 is not Sharia-compliant");
        require(token1Compliant, "Token1 is not Sharia-compliant");
    }
}
