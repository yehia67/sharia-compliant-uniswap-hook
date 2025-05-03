// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IShariaWhitelist
 * @dev Interface for the whitelist functionality of the ShariaaCompliant system
 */
interface IShariaWhitelist {
    // Structs
    struct WhitelistedToken {
        string name;
        string symbol;
        address tokenAddress;
        address whitelistedBy;
        uint256 whitelistedTime;
        bool isWhitelisted;
    }
    
    // Events
    event TokenWhitelisted(address indexed tokenAddress, string name, string symbol);
    event TokenRemovedFromWhitelist(address indexed tokenAddress);
    
    // View functions
    function whitelistedTokens(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address tokenAddress_,
        address whitelistedBy,
        uint256 whitelistedTime,
        bool isWhitelisted
    );
    function isTokenWhitelisted(address tokenAddress) external view returns (bool);
    function getTokenInfo(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address whitelistedBy,
        uint256 whitelistedTime,
        bool isWhitelisted
    );
    
    // External functions
    function emergencyRemoveFromWhitelist(address tokenAddress) external;
}
