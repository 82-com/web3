// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITokenManager {
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    event TokenAdd(address token, TokenType tokenType);
    event TokenRemoved(address token);

    function isTokenWhitelisted(address token) external view returns (bool);

    function getTokenType(address token) external view returns (TokenType);

    function getWhitelistedTokensByType(TokenType tokenType) external view returns (address[] memory);

    function addToken(address token, TokenType tokenType) external;

    function removeToken(address token) external;
}
