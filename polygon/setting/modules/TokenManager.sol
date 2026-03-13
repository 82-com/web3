// SPDX-License-Identifier: MIT
/// @title Token Manager Contract
/// @notice Abstract contract for managing token whitelisting and token type verification
/// @author Domain Team
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ITokenManager} from "../interfaces/ITokenManager.sol";

/// @title TokenManager
/// @notice Abstract contract that implements token management functionality
/// @dev This contract maintains a whitelist of tokens and their types (ERC20, ERC721, ERC1155)
abstract contract TokenManager is ITokenManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Storage slot constant for token whitelist storage
    bytes32 private constant TokenWhiteListStorageLocal = keccak256("domain.setting.token.whiteList");

    /// @notice Struct containing all token whitelist related storage
    /// @dev This struct holds a set of whitelisted token addresses and their corresponding token types
    struct TokenWhiteListStorage {
        EnumerableSet.AddressSet whitelistedTokens;
        mapping(address => TokenType) tokenTypes;
    }

    /// @notice Gets the TokenWhiteListStorage from a predefined storage slot
    /// @return twls Reference to the TokenWhiteListStorage struct
    function _getTokenWhiteListStorage() private pure returns (TokenWhiteListStorage storage twls) {
        bytes32 slot = TokenWhiteListStorageLocal;
        assembly {
            twls.slot := slot
        }
    }

    /// @notice Checks if a contract supports a specific interface
    /// @param _contract The address of the contract to check
    /// @param _interfaceId The interface identifier to check (ERC165)
    /// @return bool True if the contract supports the interface, false otherwise
    /// @dev Uses low-level staticcall to safely check interface support without reverting
    function supportsInterface(address _contract, bytes4 _interfaceId) public view returns (bool) {
        // Use low-level call to check interface support
        bool success;
        bytes memory result;
        (success, result) = _contract.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", _interfaceId));
        // Check if the call was successful and the result is true
        return success && result.length == 32 && abi.decode(result, (bool));
    }

    /// @notice Checks if a given address supports ERC20 standard
    /// @param _contract The address of the contract to check
    /// @return bool True if the contract supports ERC20, false otherwise
    /// @dev First tries to check via ERC165 interface, then falls back to calling approve function
    function checkSupportedStandardsERC20(address _contract) private returns (bool) {
        bytes4 erc20InterfaceId = 0x36372b07;
        try this.supportsInterface(_contract, erc20InterfaceId) returns (bool supported) {
            if (supported) return true;
        } catch {}
        try IERC20(_contract).approve(address(this), 0) {
            return true;
        } catch {}
        return false;
    }

    /// @notice Checks if a given address supports ERC721 standard
    /// @param _contract The address of the contract to check
    /// @return bool True if the contract supports ERC721, false otherwise
    function checkSupportedStandardsERC721(address _contract) private view returns (bool) {
        bytes4 erc721InterfaceId = 0x80ac58cd;
        return supportsInterface(_contract, erc721InterfaceId);
    }

    /// @notice Checks if a given address supports ERC1155 standard
    /// @param _contract The address of the contract to check
    /// @return bool True if the contract supports ERC1155, false otherwise
    function checkSupportedStandardsERC1155(address _contract) private view returns (bool) {
        bytes4 erc1155InterfaceId = 0xd9b66c1b;
        return supportsInterface(_contract, erc1155InterfaceId);
    }

    /// @notice Checks if a token is whitelisted
    /// @param token The address of the token to check
    /// @return bool True if token is whitelisted, false otherwise
    function isTokenWhitelisted(address token) public view virtual returns (bool) {
        return _getTokenWhiteListStorage().whitelistedTokens.contains(token);
    }

    /// @notice Gets the type of a token
    /// @param token The address of the token
    /// @return TokenType The type of the token (ERC20, ERC721, ERC1155)
    function getTokenType(address token) public view virtual returns (TokenType) {
        return _getTokenWhiteListStorage().tokenTypes[token];
    }

    /// @notice Retrieves all whitelisted tokens of a specific TokenType
    /// @param tokenType The type of token to filter by
    /// @return result Array of token addresses matching the specified TokenType
    function getWhitelistedTokensByType(TokenType tokenType) public view virtual returns (address[] memory) {
        TokenWhiteListStorage storage twls = _getTokenWhiteListStorage();

        uint256 totalItems = twls.whitelistedTokens.length();
        address[] memory currencies = new address[](totalItems);
        uint256 count = 0;

        for (uint256 i = 0; i < totalItems; i++) {
            address currency = twls.whitelistedTokens.at(i);
            if (twls.tokenTypes[currency] == tokenType) {
                currencies[count] = currency;
                count++;
            }
        }

        // Resize the array to the actual number of matching tokens
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = currencies[i];
        }

        return result;
    }

    /// @notice Adds a token to the whitelist
    /// @param token The address of the token to whitelist
    /// @param tokenType The type of the token (ERC20, ERC721, ERC1155)
    /// @dev Only callable by TOKEN_MANAGER_ROLE
    /// @custom:reverts InvalidTokenAddress If token address is invalid or doesn't match the specified type
    /// @custom:reverts TokenAlreadyWhitelisted If token is already whitelisted
    function _addToken(address token, TokenType tokenType) internal {
        if (token.code.length == 0) revert("Invalid token address");

        TokenWhiteListStorage storage twls = _getTokenWhiteListStorage();
        if (twls.whitelistedTokens.contains(token)) revert("Token already whitelisted");
        if (tokenType == TokenType.ERC20) {
            if (!checkSupportedStandardsERC20(token)) revert("Invalid token address");
        } else if (tokenType == TokenType.ERC721) {
            if (!checkSupportedStandardsERC721(token)) revert("Invalid token address");
        } else if (tokenType == TokenType.ERC1155) {
            if (!checkSupportedStandardsERC1155(token)) revert("Invalid token address");
        }
        twls.whitelistedTokens.add(token);
        twls.tokenTypes[token] = tokenType;
        emit TokenAdd(token, tokenType);
    }

    /// @notice Removes a token from the whitelist
    /// @param token The address of the token to remove
    /// @dev Only callable by TOKEN_MANAGER_ROLE
    /// @custom:reverts TokenNotWhitelisted If token is not in whitelist
    function _removeToken(address token) internal {
        TokenWhiteListStorage storage twls = _getTokenWhiteListStorage();
        if (!twls.whitelistedTokens.contains(token)) revert("Token not whitelisted");
        twls.whitelistedTokens.remove(token);
        emit TokenRemoved(token);
    }
}
