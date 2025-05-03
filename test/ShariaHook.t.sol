// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import "forge-std/console.sol";
import {ShariaHook} from "../src/ShariaHook.sol";
import {IShariaWhitelist} from "../src/interfaces/IShariaWhitelist.sol";

// Mock whitelist contract for testing
contract MockShariaWhitelist is IShariaWhitelist {
    mapping(address => WhitelistedToken) private _whitelistedTokens;
    
    function whitelistToken(
        address tokenAddress,
        string calldata name,
        string calldata symbol,
        address whitelistedBy,
        uint256 whitelistedTime
    ) external {
        _whitelistedTokens[tokenAddress] = WhitelistedToken({
            name: name,
            symbol: symbol,
            tokenAddress: tokenAddress,
            whitelistedBy: whitelistedBy,
            whitelistedTime: whitelistedTime,
            isWhitelisted: true
        });
        emit TokenWhitelisted(tokenAddress, name, symbol);
    }
    
    function emergencyRemoveFromWhitelist(address tokenAddress) external {
        _whitelistedTokens[tokenAddress].isWhitelisted = false;
        emit TokenRemovedFromWhitelist(tokenAddress);
    }
    
    function whitelistedTokens(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address tokenAddress_,
        address whitelistedBy,
        uint256 whitelistedTime,
        bool isWhitelisted
    ) {
        WhitelistedToken memory token = _whitelistedTokens[tokenAddress];
        return (
            token.name,
            token.symbol,
            token.tokenAddress,
            token.whitelistedBy,
            token.whitelistedTime,
            token.isWhitelisted
        );
    }
    
    function isTokenWhitelisted(address tokenAddress) external view returns (bool) {
        return _whitelistedTokens[tokenAddress].isWhitelisted;
    }
    
    function getTokenInfo(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address whitelistedBy,
        uint256 whitelistedTime,
        bool isWhitelisted
    ) {
        WhitelistedToken memory token = _whitelistedTokens[tokenAddress];
        return (
            token.name,
            token.symbol,
            token.whitelistedBy,
            token.whitelistedTime,
            token.isWhitelisted
        );
    }
}

contract TestShariaHook is Test, Deployers {
	using CurrencyLibrary for Currency;

	MockERC20 token; // our token to use in the ETH-TOKEN pool
    MockERC20 nonCompliantToken; // token that is not whitelisted

	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;
    Currency nonCompliantTokenCurrency;

	ShariaHook hook;
    MockShariaWhitelist whitelist;

	function setUp() public {
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));
        
        // Deploy a non-compliant token
        nonCompliantToken = new MockERC20("Non-Compliant Token", "NCT", 18);
        nonCompliantTokenCurrency = Currency.wrap(address(nonCompliantToken));

        // Mint tokens to ourselves
        token.mint(address(this), 1000 ether);
        nonCompliantToken.mint(address(this), 1000 ether);

        // Deploy the mock whitelist contract
        whitelist = new MockShariaWhitelist();
        
        // Whitelist our test token
        whitelist.whitelistToken(
            address(token),
            "Test Token",
            "TEST",
            address(this),
            block.timestamp
        );

        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
        );
        deployCodeTo(
            "ShariaHook.sol",
            abi.encode(manager, address(whitelist)),
            address(flags)
        );

        // Deploy our hook
        hook = ShariaHook(address(flags));

        // Approve our TOKEN for spending on the swap router and modify liquidity router
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);
        nonCompliantToken.approve(address(swapRouter), type(uint256).max);
        nonCompliantToken.approve(address(modifyLiquidityRouter), type(uint256).max);

        // Initialize a pool with compliant token
        (key, ) = initPool(
            ethCurrency, // Currency 0 = ETH
            tokenCurrency, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
        );
    }

    function test_addLiquidityWithCompliantToken() public {
        bytes memory hookData = abi.encode(address(this));

        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint256 ethToAdd = 0.1 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            ethToAdd
        );

        // Should succeed because token is whitelisted
        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            hookData
        );
        
        // If we got here without reverting, the test passes
        assertTrue(true, "Adding liquidity with compliant token should succeed");
    }
    
    function test_swapWithCompliantToken() public {
        // First add liquidity to have something to swap against
        bytes memory hookData = abi.encode(address(this));

        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint256 ethToAdd = 0.1 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            ethToAdd
        );

        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            hookData
        );

        // Should succeed because token is whitelisted
        swapRouter.swap{value: 0.001 ether}(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        
        // If we got here without reverting, the test passes
        assertTrue(true, "Swapping with compliant token should succeed");
    }
}