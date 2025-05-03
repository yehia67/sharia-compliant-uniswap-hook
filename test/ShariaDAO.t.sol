// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {ShariaDAO} from "../src/ShariaDAO.sol";
import {ShariaWhitelist} from "../src/ShariaWhitelist.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract TestShariaDAO is Test {
    ShariaDAO dao;
    ShariaWhitelist whitelist;
    MockERC20 token;

    address owner = address(1);
    address mufti = address(2);
    address regularUser = address(3);

    function setUp() public {
        // Deploy the whitelist contract first
        vm.startPrank(owner);
        whitelist = new ShariaWhitelist();

        // Deploy the DAO with reference to the whitelist
        dao = new ShariaDAO(address(whitelist));

        // Set the DAO as the authorized contract in the whitelist
        whitelist.setDAOContract(address(dao));

        // Add a mufti to the DAO
        dao.addMufti(mufti);
        vm.stopPrank();

        // Deploy a test token that will be proposed for whitelisting
        token = new MockERC20("Test Sharia Token", "TST", 18);
    }

    function test_addMufti() public {
        vm.startPrank(owner);
        address newMufti = address(4);
        dao.addMufti(newMufti);
        vm.stopPrank();

        // Check that the new mufti has the MUFTI_ROLE
        assertTrue(dao.hasRole(dao.MUFTI_ROLE(), newMufti));

        // Check that the new mufti has initial reputation
        assertEq(dao.getUserReputation(newMufti), 5);
    }

    function test_removeMufti() public {
        vm.startPrank(owner);
        dao.removeMufti(mufti);
        vm.stopPrank();

        // Check that the mufti no longer has the MUFTI_ROLE
        assertFalse(dao.hasRole(dao.MUFTI_ROLE(), mufti));
    }

    function test_proposeToken() public {
        vm.startPrank(mufti);
        dao.proposeToken(address(token), "Test Sharia Token", "TST", "ipfs://QmTest123");
        vm.stopPrank();

        // Check that the proposal was created
        (address proposer, address tokenAddress,,,,,,) = dao.getProposalInfo(0);
        assertEq(proposer, mufti);
        assertEq(tokenAddress, address(token));
    }

    function test_voteOnProposal() public {
        // First create a proposal
        vm.startPrank(mufti);
        dao.proposeToken(address(token), "Test Sharia Token", "TST", "ipfs://QmTest123");
        vm.stopPrank();

        // Grant reputation to another mufti so they can vote
        vm.startPrank(owner);
        address voter = address(5);
        dao.addMufti(voter);
        vm.stopPrank();

        // Vote on the proposal
        vm.startPrank(voter);
        dao.vote(0, true);
        vm.stopPrank();

        // Check that the vote was counted
        (,,,,, uint256 yesVotes, uint256 noVotes,) = dao.getProposalInfo(0);
        // The vote weight is calculated using sqrt(reputation * 10^18) / 10^9
        // For reputation = 5, this gives sqrt(5 * 10^18) / 10^9 ≈ 2.2 * 10^9 / 10^9 ≈ 2
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);
    }

    function test_finalizeProposal() public {
        // First create a proposal
        vm.startPrank(mufti);
        dao.proposeToken(address(token), "Test Sharia Token", "TST", "ipfs://QmTest123");
        vm.stopPrank();

        // First, lower the quorum requirement to make the test pass
        vm.startPrank(owner);
        dao.setGovernanceParameters(
            7 days, // keep the same voting period
            1, // keep the same min reputation
            4, // lower quorum to 4 instead of 10
            5 // keep the same reputation reward
        );

        // Add enough votes to pass the proposal
        address voter1 = address(5);
        address voter2 = address(6);
        dao.addMufti(voter1);
        dao.addMufti(voter2);
        vm.stopPrank();

        vm.startPrank(voter1);
        dao.vote(0, true);
        vm.stopPrank();

        vm.startPrank(voter2);
        dao.vote(0, true);
        vm.stopPrank();

        // Fast forward time to after the voting period
        vm.warp(block.timestamp + 8 days);

        // Finalize the proposal
        dao.finalizeProposal(0);

        // Check that the token is now whitelisted
        assertTrue(whitelist.isTokenWhitelisted(address(token)));

        // Check that the proposer got reputation reward
        uint256 muftiReputation = dao.getUserReputation(mufti);
        assertEq(muftiReputation, 10); // 5 initial + 5 reward
    }

    function test_setGovernanceParameters() public {
        vm.startPrank(owner);
        dao.setGovernanceParameters(
            14 days, // new voting period
            2, // new min reputation
            20, // new quorum
            10 // new reputation reward
        );
        vm.stopPrank();

        // Check that the parameters were updated
        assertEq(dao.votingPeriod(), 14 days);
        assertEq(dao.minReputation(), 2);
        assertEq(dao.quorum(), 20);
        assertEq(dao.reputationReward(), 10);
    }

    function test_grantInitialReputation() public {
        vm.startPrank(owner);
        dao.grantInitialReputation(regularUser, 3);
        vm.stopPrank();

        // Check that the user received the reputation
        assertEq(dao.getUserReputation(regularUser), 3);
    }

    function test_RevertWhen_NonMuftiProposesToken() public {
        vm.startPrank(regularUser);
        bytes32 role = dao.MUFTI_ROLE();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", regularUser, role));
        dao.proposeToken(address(token), "Test Sharia Token", "TST", "ipfs://QmTest123");
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerAddsMufti() public {
        vm.startPrank(regularUser);
        bytes32 role = dao.OWNER_ROLE();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", regularUser, role));
        dao.addMufti(address(7));
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientReputationVotes() public {
        // First create a proposal
        vm.startPrank(mufti);
        dao.proposeToken(address(token), "Test Sharia Token", "TST", "ipfs://QmTest123");
        vm.stopPrank();

        // Try to vote with a user who has no reputation
        vm.startPrank(regularUser);
        vm.expectRevert("Insufficient reputation to perform this action");
        dao.vote(0, true);
        vm.stopPrank();
    }
}
