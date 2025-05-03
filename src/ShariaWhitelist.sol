// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IShariaWhitelist.sol";

/**
 * @title ShariaWhitelist
 * @dev Implementation of the whitelist functionality for Sharia-compliant tokens
 */
contract ShariaWhitelist is IShariaWhitelist, AccessControl, ReentrancyGuard {
    // Role definitions
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    
    // State variables
    mapping(address => WhitelistedToken) public whitelistedTokens;
    
    /**
     * @dev Constructor sets the initial roles
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);
    }
    
    /**
     * @dev Grant DAO role to the DAO contract
     * @param daoAddress Address of the DAO contract
     */
    function setDAOContract(address daoAddress) external onlyRole(OWNER_ROLE) {
        require(daoAddress != address(0), "Invalid DAO address");
        _grantRole(DAO_ROLE, daoAddress);
    }
    
    /**
     * @dev Whitelist a token (can only be called by the DAO contract)
     * @param tokenAddress Address of the token to whitelist
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param whitelistedBy Address that proposed the token
     * @param whitelistedTime Time when the token was whitelisted
     */
    function whitelistToken(
        address tokenAddress,
        string calldata name,
        string calldata symbol,
        address whitelistedBy,
        uint256 whitelistedTime
    ) external onlyRole(DAO_ROLE) {
        require(tokenAddress != address(0), "Invalid token address");
        require(!whitelistedTokens[tokenAddress].isWhitelisted, "Token already whitelisted");
        
        whitelistedTokens[tokenAddress] = WhitelistedToken({
            name: name,
            symbol: symbol,
            tokenAddress: tokenAddress,
            whitelistedBy: whitelistedBy,
            whitelistedTime: whitelistedTime,
            isWhitelisted: true
        });
        
        emit TokenWhitelisted(tokenAddress, name, symbol);
    }
    
    /**
     * @dev Emergency function to remove a token from whitelist (owner only)
     * @param tokenAddress The address of the token to remove
     */
    function emergencyRemoveFromWhitelist(address tokenAddress) external onlyRole(OWNER_ROLE) {
        require(whitelistedTokens[tokenAddress].isWhitelisted, "Token is not whitelisted");
        
        whitelistedTokens[tokenAddress].isWhitelisted = false;
        
        emit TokenRemovedFromWhitelist(tokenAddress);
    }
    
    /**
     * @dev Check if a token is whitelisted
     * @param tokenAddress The address of the token to check
     * @return Whether the token is whitelisted
     */
    function isTokenWhitelisted(address tokenAddress) external view returns (bool) {
        return whitelistedTokens[tokenAddress].isWhitelisted;
    }
    
    /**
     * @dev Get token whitelist information
     * @param tokenAddress The address of the token to get info for
     * @return name The name of the whitelisted token
     * @return symbol The symbol of the whitelisted token
     * @return whitelistedBy The address that proposed the token for whitelisting
     * @return whitelistedTime The timestamp when the token was whitelisted
     * @return isWhitelisted Whether the token is currently whitelisted
     */
    function getTokenInfo(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address whitelistedBy,
        uint256 whitelistedTime,
        bool isWhitelisted
    ) {
        WhitelistedToken memory token = whitelistedTokens[tokenAddress];
        return (
            token.name,
            token.symbol,
            token.whitelistedBy,
            token.whitelistedTime,
            token.isWhitelisted
        );
    }
}
