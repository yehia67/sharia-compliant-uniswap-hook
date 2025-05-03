// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {ShariaWhitelist} from "../src/ShariaWhitelist.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract TestShariaWhitelist is Test {
    ShariaWhitelist whitelist;
    MockERC20 token;

    address owner = address(1);
    address daoContract = address(2);
    address whitelistedBy = address(3);

    function setUp() public {
        // Deploy the whitelist contract
        vm.startPrank(owner);
        whitelist = new ShariaWhitelist();
        
        // Set the DAO contract
        whitelist.setDAOContract(daoContract);
        vm.stopPrank();

        // Deploy a test token that will be whitelisted
        token = new MockERC20("Test Sharia Token", "TST", 18);
    }

    function test_setDAOContract() public {
        vm.startPrank(owner);
        address newDAO = address(4);
        whitelist.setDAOContract(newDAO);
        vm.stopPrank();

        // Check that the new DAO has the DAO_ROLE
        assertTrue(whitelist.hasRole(whitelist.DAO_ROLE(), newDAO));
    }

    function test_whitelistToken() public {
        // Only the DAO contract can whitelist tokens
        vm.startPrank(daoContract);
        whitelist.whitelistToken(
            address(token),
            "Test Sharia Token",
            "TST",
            whitelistedBy,
            block.timestamp
        );
        vm.stopPrank();

        // Check that the token is whitelisted
        assertTrue(whitelist.isTokenWhitelisted(address(token)));

        // Check the token info
        (string memory name, string memory symbol, address by, uint256 time, bool isWhitelisted) = 
            whitelist.getTokenInfo(address(token));
        
        assertEq(name, "Test Sharia Token");
        assertEq(symbol, "TST");
        assertEq(by, whitelistedBy);
        assertEq(time, block.timestamp);
        assertTrue(isWhitelisted);
    }

    function test_emergencyRemoveFromWhitelist() public {
        // First whitelist a token
        vm.startPrank(daoContract);
        whitelist.whitelistToken(
            address(token),
            "Test Sharia Token",
            "TST",
            whitelistedBy,
            block.timestamp
        );
        vm.stopPrank();

        // Now emergency remove it
        vm.startPrank(owner);
        whitelist.emergencyRemoveFromWhitelist(address(token));
        vm.stopPrank();

        // Check that the token is no longer whitelisted
        assertFalse(whitelist.isTokenWhitelisted(address(token)));

        // Check the token info
        (,,,,bool isWhitelisted) = whitelist.getTokenInfo(address(token));
        assertFalse(isWhitelisted);
    }

    function testFail_nonDAOCannotWhitelistToken() public {
        // Try to whitelist a token from a non-DAO address
        vm.startPrank(owner);
        whitelist.whitelistToken(
            address(token),
            "Test Sharia Token",
            "TST",
            whitelistedBy,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testFail_nonOwnerCannotSetDAOContract() public {
        // Try to set the DAO contract from a non-owner address
        vm.startPrank(address(5));
        whitelist.setDAOContract(address(6));
        vm.stopPrank();
    }

    function testFail_nonOwnerCannotEmergencyRemove() public {
        // First whitelist a token
        vm.startPrank(daoContract);
        whitelist.whitelistToken(
            address(token),
            "Test Sharia Token",
            "TST",
            whitelistedBy,
            block.timestamp
        );
        vm.stopPrank();

        // Try to emergency remove it from a non-owner address
        vm.startPrank(address(5));
        whitelist.emergencyRemoveFromWhitelist(address(token));
        vm.stopPrank();
    }

    function test_cannotWhitelistTokenTwice() public {
        // First whitelist a token
        vm.startPrank(daoContract);
        whitelist.whitelistToken(
            address(token),
            "Test Sharia Token",
            "TST",
            whitelistedBy,
            block.timestamp
        );
        vm.stopPrank();

        // Try to whitelist it again
        vm.startPrank(daoContract);
        vm.expectRevert("Token already whitelisted");
        whitelist.whitelistToken(
            address(token),
            "Test Sharia Token",
            "TST",
            whitelistedBy,
            block.timestamp
        );
        vm.stopPrank();
    }
}
