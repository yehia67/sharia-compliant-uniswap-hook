// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IShariaDAO.sol";
import "./interfaces/IShariaWhitelist.sol";

/**
 * @title ShariaDAO
 * @dev A DAO-based system for managing Sharia-compliant tokens with reputation-based voting
 */
contract ShariaDAO is IShariaDAO, AccessControl, ReentrancyGuard {
    // Role definitions
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MUFTI_ROLE = keccak256("MUFTI_ROLE");

    // Proposal struct
    struct Proposal {
        address proposer;
        address tokenAddress;
        string tokenName;
        string tokenSymbol;
        string complianceDocumentation;
        uint256 proposalTime;
        uint256 votingDeadline;
        uint256 yesVotes;
        uint256 noVotes;
        ProposalStatus status;
        mapping(address => bool) hasVoted;
    }

    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public reputation;

    uint256 public proposalCount;
    uint256 public votingPeriod = 7 days;
    uint256 public minReputation = 1;
    uint256 public quorum = 10; // Minimum total votes needed
    uint256 public reputationReward = 5; // Reputation gained for successful proposal

    // Reference to the whitelist contract
    IShariaWhitelist public whitelistContract;

    /**
     * @dev Constructor sets the initial roles
     */
    constructor(address _whitelistContract) {
        require(_whitelistContract != address(0), "Invalid whitelist contract address");
        whitelistContract = IShariaWhitelist(_whitelistContract);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);

        // Give the contract creator initial reputation
        reputation[msg.sender] = 10;
    }

    /**
     * @dev Modifier to check if the caller has enough reputation to vote
     */
    modifier hasMinimumReputation() {
        require(reputation[msg.sender] >= minReputation, "Insufficient reputation to perform this action");
        _;
    }

    /**
     * @dev Allow owner to add a Mufti who can propose tokens
     * @param mufti Address of the Mufti to be added
     */
    function addMufti(address mufti) external onlyRole(OWNER_ROLE) {
        require(mufti != address(0), "Invalid address");
        _grantRole(MUFTI_ROLE, mufti);

        // Grant initial reputation to Mufti
        if (reputation[mufti] == 0) {
            reputation[mufti] = 5;
            emit ReputationChanged(mufti, 5);
        }

        emit MuftiAdded(mufti);
    }

    /**
     * @dev Allow owner to remove a Mufti
     * @param mufti Address of the Mufti to be removed
     */
    function removeMufti(address mufti) external onlyRole(OWNER_ROLE) {
        _revokeRole(MUFTI_ROLE, mufti);
        emit MuftiRemoved(mufti);
    }

    /**
     * @dev Create a proposal to whitelist a token
     * @param tokenAddress Address of the token contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param complianceDocumentation IPFS hash or URL to documentation proving Sharia compliance
     */
    function proposeToken(
        address tokenAddress,
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata complianceDocumentation
    ) external onlyRole(MUFTI_ROLE) hasMinimumReputation nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(bytes(tokenName).length > 0, "Token name cannot be empty");
        require(bytes(tokenSymbol).length > 0, "Token symbol cannot be empty");
        require(bytes(complianceDocumentation).length > 0, "Compliance documentation required");
        require(!whitelistContract.isTokenWhitelisted(tokenAddress), "Token already whitelisted");

        // Validate token contract has required ERC20 functions
        try IERC20(tokenAddress).totalSupply() returns (uint256) {
            // Successfully called totalSupply, token implements ERC20
        } catch {
            revert("Address is not a valid ERC20 token");
        }

        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.proposer = msg.sender;
        newProposal.tokenAddress = tokenAddress;
        newProposal.tokenName = tokenName;
        newProposal.tokenSymbol = tokenSymbol;
        newProposal.complianceDocumentation = complianceDocumentation;
        newProposal.proposalTime = block.timestamp;
        newProposal.votingDeadline = block.timestamp + votingPeriod;
        newProposal.status = ProposalStatus.Active;

        proposalCount++;

        emit ProposalCreated(proposalId, msg.sender, tokenAddress);
    }

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param support Whether to vote in favor (true) or against (false)
     */
    function vote(uint256 proposalId, bool support) external hasMinimumReputation nonReentrant {
        require(proposalId < proposalCount, "Proposal does not exist");

        Proposal storage proposal = proposals[proposalId];

        require(proposal.status == ProposalStatus.Active, "Proposal is not active");
        require(block.timestamp < proposal.votingDeadline, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        // Calculate vote weight based on reputation (sqrt of reputation for non-linear scaling)
        uint256 voteWeight = Math.sqrt(reputation[msg.sender] * 10 ** 18) / 10 ** 9;
        if (voteWeight == 0) voteWeight = 1; // Minimum vote weight is 1

        if (support) {
            proposal.yesVotes += voteWeight;
        } else {
            proposal.noVotes += voteWeight;
        }

        proposal.hasVoted[msg.sender] = true;

        emit Voted(proposalId, msg.sender, support, voteWeight);
    }

    /**
     * @dev Finalize a proposal after voting period ends
     * @param proposalId The ID of the proposal to finalize
     */
    function finalizeProposal(uint256 proposalId) external nonReentrant {
        require(proposalId < proposalCount, "Proposal does not exist");

        Proposal storage proposal = proposals[proposalId];

        require(proposal.status == ProposalStatus.Active, "Proposal is not active");
        require(block.timestamp >= proposal.votingDeadline, "Voting period has not ended");

        bool passed = false;
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;

        // Check if quorum reached and majority in favor
        if (totalVotes >= quorum && proposal.yesVotes > proposal.noVotes) {
            passed = true;

            // Call the whitelist contract to whitelist the token
            (bool success,) = address(whitelistContract).call(
                abi.encodeWithSignature(
                    "whitelistToken(address,string,string,address,uint256)",
                    proposal.tokenAddress,
                    proposal.tokenName,
                    proposal.tokenSymbol,
                    proposal.proposer,
                    block.timestamp
                )
            );
            require(success, "Failed to whitelist token");

            // Reward proposer with additional reputation
            reputation[proposal.proposer] += reputationReward;
            emit ReputationChanged(proposal.proposer, reputation[proposal.proposer]);

            proposal.status = ProposalStatus.Executed;
        } else {
            proposal.status = ProposalStatus.Rejected;
        }

        emit ProposalExecuted(proposalId, proposal.tokenAddress, passed);
    }

    /**
     * @dev Get a user's reputation
     * @param user The address of the user
     * @return The user's reputation score
     */
    function getUserReputation(address user) external view returns (uint256) {
        return reputation[user];
    }

    /**
     * @dev Get proposal details
     * @param proposalId The ID of the proposal
     * @return proposer The address of the proposal creator
     * @return tokenAddress The address of the token being proposed
     * @return tokenName The name of the token
     * @return tokenSymbol The symbol of the token
     * @return votingDeadline The timestamp when voting ends
     * @return yesVotes The number of votes in favor
     * @return noVotes The number of votes against
     * @return status The current status of the proposal
     */
    function getProposalInfo(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            address tokenAddress,
            string memory tokenName,
            string memory tokenSymbol,
            uint256 votingDeadline,
            uint256 yesVotes,
            uint256 noVotes,
            ProposalStatus status
        )
    {
        require(proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];

        return (
            proposal.proposer,
            proposal.tokenAddress,
            proposal.tokenName,
            proposal.tokenSymbol,
            proposal.votingDeadline,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.status
        );
    }

    /**
     * @dev Set governance parameters (owner only)
     * @param newVotingPeriod New voting period duration in seconds
     * @param newMinReputation Minimum reputation required to participate
     * @param newQuorum Minimum total votes needed for a valid proposal
     * @param newReputationReward Reputation reward for successful proposals
     */
    function setGovernanceParameters(
        uint256 newVotingPeriod,
        uint256 newMinReputation,
        uint256 newQuorum,
        uint256 newReputationReward
    ) external onlyRole(OWNER_ROLE) {
        require(newVotingPeriod >= 1 days, "Voting period too short");

        votingPeriod = newVotingPeriod;
        minReputation = newMinReputation;
        quorum = newQuorum;
        reputationReward = newReputationReward;
    }

    /**
     * @dev Grant initial reputation to a new user (owner only)
     * @param user Address of the user
     * @param initialReputation Amount of reputation to grant
     */
    function grantInitialReputation(address user, uint256 initialReputation) external onlyRole(OWNER_ROLE) {
        require(user != address(0), "Invalid address");
        require(reputation[user] == 0, "User already has reputation");

        reputation[user] = initialReputation;
        emit ReputationChanged(user, initialReputation);
    }
}
