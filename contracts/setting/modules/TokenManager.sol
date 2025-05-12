// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TokenManager
 * @notice Module for managing whitelisted tokens in the system
 * @dev Provides functionality to:
 * - Add/remove tokens from whitelist with type validation (ERC20/ERC721/ERC1155)
 * - Check token whitelist status and type
 * - View filtered lists of whitelisted tokens by type
 * Uses EnumerableSet for efficient storage and retrieval
 */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SettingERROR} from "./SettingERROR.sol";

abstract contract TokenManager is SettingERROR {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @dev Supported token standards in the system
     * @param ERC20 Standard fungible token interface
     * @param ERC721 Standard non-fungible token interface
     * @param ERC1155 Multi-token standard supporting both fungible and non-fungible tokens
     */
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    // ************************************
    // *           Storage               *
    // ************************************

    /// @dev Mapping of token addresses to token type
    mapping(address => TokenType) internal _tokenTypes;

    /// @dev Set of approved trading currencies
    EnumerableSet.AddressSet internal _whitelistedTokens;

    // ************************************
    // *           Events                *
    // ************************************

    /**
     * @notice Emitted when a token is added to the whitelist
     * @param token The address of the token that was added
     * @param tokenType The type of token that was added (ERC20/ERC721/ERC1155)
     */
    event TokenAdd(address token, TokenType tokenType);

    /**
     * @notice Emitted when a token is removed from the whitelist
     * @param token The address of the token that was removed
     */
    event TokenRemoved(address token);

    /**
     * @notice Checks if a contract supports a specific interface
     * @param _contract The address of the contract to check
     * @param _interfaceId The interface identifier to check (ERC165)
     * @return bool True if the contract supports the interface, false otherwise
     * @dev Uses low-level staticcall to safely check interface support without reverting
     */
    function supportsInterface(address _contract, bytes4 _interfaceId) public view returns (bool) {
        // Use low-level call to check interface support
        bool success;
        bytes memory result;
        (success, result) = _contract.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", _interfaceId));
        // Check if the call was successful and the result is true
        return success && result.length == 32 && abi.decode(result, (bool));
    }

    /**
     * @notice Checks if a given address supports ERC20
     * @param _contract address to check
     * @return bool true if the contract supports ERC20, false otherwise
     */
    function checkSupportedStandardsERC20(address _contract) public returns (bool) {
        bytes4 erc20InterfaceId = 0x36372b07;
        try this.supportsInterface(_contract, erc20InterfaceId) returns (bool supported) {
            if (supported) return true;
        } catch {}
        try IERC20(_contract).approve(address(this), 0) {
            return true;
        } catch {}
        return false;
    }

    /**
     * @notice Checks if a given address supports ERC721
     * @param _contract address to check
     * @return bool true if the contract supports ERC721, false otherwise
     */
    function checkSupportedStandardsERC721(address _contract) public view returns (bool) {
        bytes4 erc721InterfaceId = 0x80ac58cd;
        return supportsInterface(_contract, erc721InterfaceId);
    }

    /**
     * @notice Checks if a given address supports ERC1155
     * @param _contract address to check
     * @return bool true if the contract supports ERC1155, false otherwise
     */
    function checkSupportedStandardsERC1155(address _contract) public view returns (bool) {
        bytes4 erc1155InterfaceId = 0xd9b66c1b;
        return supportsInterface(_contract, erc1155InterfaceId);
    }

    /**
     * @notice Adds a token to the whitelist
     * @param token Address of the token to whitelist
     * @param tokenType Type of the token (ERC20, ERC721, ERC1155)
     * @dev Only callable by TOKEN_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If token already whitelisted
     */
    function _addToken(address token, TokenType tokenType) internal nonZeroAddress(token) {
        if (_whitelistedTokens.contains(token)) {
            revert AlreadyWhitelisted(token);
        }
        // Check if it's a contract
        if (token.code.length == 0) revert InvalidToken(token);
        if (tokenType == TokenType.ERC20) {
            if (!checkSupportedStandardsERC20(token)) {
                revert InvalidToken(token);
            }
        } else if (tokenType == TokenType.ERC721) {
            if (!checkSupportedStandardsERC721(token)) {
                revert InvalidToken(token);
            }
        } else if (tokenType == TokenType.ERC1155) {
            if (!checkSupportedStandardsERC1155(token)) {
                revert InvalidToken(token);
            }
        }
        _whitelistedTokens.add(token);
        _tokenTypes[token] = tokenType;
        emit TokenAdd(token, tokenType);
    }

    /**
     * @notice Removes a token from the whitelist
     * @param token Address of the token to remove
     * @dev Only callable by TOKEN_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If token not in whitelist
     */
    function _removeToken(address token) internal {
        if (!_whitelistedTokens.contains(token)) {
            revert NotWhitelisted(token);
        }
        _whitelistedTokens.remove(token);
        emit TokenRemoved(token);
    }

    /**
     * @notice Checks if a token is whitelisted
     * @param token Address of the token to check
     * @return bool True if token is whitelisted
     */
    function isTokenWhitelisted(address token) external view virtual returns (bool) {
        return _whitelistedTokens.contains(token);
    }

    /**
     * @notice Gets the type of a token
     * @param token Address of the token
     * @return TokenType Type of the token
     */
    function getTokenType(address token) external view virtual returns (TokenType) {
        return _tokenTypes[token];
    }

    /**
     * @notice Retrieves all whitelisted tokens of a specific TokenType
     * @param tokenType The type of token to filter by
     * @return result Array of token addresses matching the specified TokenType
     */
    function viewWhitelistedTokensByType(TokenType tokenType) external view virtual returns (address[] memory) {
        uint256 totalItems = _whitelistedTokens.length();
        address[] memory currencies = new address[](totalItems);
        uint256 count = 0;

        for (uint256 i = 0; i < totalItems; i++) {
            address currency = _whitelistedTokens.at(i);
            if (_tokenTypes[currency] == tokenType) {
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

    uint256[8] private __gap;
}
