// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IShariaDAO
 * @dev Interface for the DAO governance features of the ShariaaCompliant system
 */
interface IShariaDAO {
    // Enums
    enum ProposalStatus {
        Pending,
        Active,
        Passed,
        Rejected,
        Executed
    }

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address tokenAddress);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address tokenAddress, bool approved);
    event ReputationChanged(address indexed user, uint256 newReputation);
    event MuftiAdded(address indexed mufti);
    event MuftiRemoved(address indexed mufti);

    // View functions
    function OWNER_ROLE() external view returns (bytes32);
    function MUFTI_ROLE() external view returns (bytes32);
    function proposals(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            address tokenAddress,
            string memory tokenName,
            string memory tokenSymbol,
            string memory complianceDocumentation,
            uint256 proposalTime,
            uint256 votingDeadline,
            uint256 yesVotes,
            uint256 noVotes,
            ProposalStatus status
        );
    function reputation(address user) external view returns (uint256);
    function proposalCount() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function minReputation() external view returns (uint256);
    function quorum() external view returns (uint256);
    function reputationReward() external view returns (uint256);
    function getUserReputation(address user) external view returns (uint256);
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
        );

    // External functions
    function addMufti(address mufti) external;
    function removeMufti(address mufti) external;
    function proposeToken(
        address tokenAddress,
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata complianceDocumentation
    ) external;
    function vote(uint256 proposalId, bool support) external;
    function finalizeProposal(uint256 proposalId) external;
    function setGovernanceParameters(
        uint256 newVotingPeriod,
        uint256 newMinReputation,
        uint256 newQuorum,
        uint256 newReputationReward
    ) external;
    function grantInitialReputation(address user, uint256 initialReputation) external;
}
