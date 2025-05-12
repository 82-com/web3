// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TransferAgentManager
 * @notice Module for managing whitelisted transfer agent exchanges in the system
 * @dev Provides functionality to:
 * - Add/remove exchange addresses from transfer agent whitelist
 * - Check exchange whitelist status
 * - View all whitelisted exchanges
 * Uses EnumerableSet for efficient storage and retrieval
 */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SettingERROR} from "./SettingERROR.sol";

abstract contract TransferAgentManager is SettingERROR {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ************************************
    // *           Storage               *
    // ************************************

    /// @dev Set of approved exchange wallets
    EnumerableSet.AddressSet internal _whitelistedExchanges;

    // ************************************
    // *           Events                *
    // ************************************

    /**
     * @notice Emitted when an exchange is added to the transfer agent whitelist
     * @param exchange The address of the exchange that was added
     */
    event TransferAgentExchangeAdd(address exchange);

    /**
     * @notice Emitted when an exchange is removed from the transfer agent whitelist
     * @param exchange The address of the exchange that was removed
     */
    event TransferAgentExchangeRemoved(address exchange);

    /**
     * @notice Adds a exchange to the whitelist
     * @param exchange Address of the exchange to whitelist
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If exchange already whitelisted
     */
    function _addTransferAgentExchange(address exchange) internal nonZeroAddress(exchange) {
        if (_whitelistedExchanges.contains(exchange)) {
            revert AlreadyWhitelisted(exchange);
        }
        _whitelistedExchanges.add(exchange);
        emit TransferAgentExchangeAdd(exchange);
    }

    /**
     * @notice Removes a exchange from the whitelist
     * @param exchange Address of the exchange to remove
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If exchange not in whitelist
     */
    function _removeTransferAgentExchange(address exchange) internal {
        if (!_whitelistedExchanges.contains(exchange)) {
            revert NotWhitelisted(exchange);
        }
        _whitelistedExchanges.remove(exchange);
        emit TransferAgentExchangeRemoved(exchange);
    }

    /**
     * @notice Checks if a exchange is whitelisted
     * @param exchange Address of the exchange to check
     * @return bool True if exchange is whitelisted
     */
    function isTransferAgentExchange(address exchange) external view virtual returns (bool) {
        return _whitelistedExchanges.contains(exchange);
    }

    /**
     * @notice Gets the count of approved exchanges
     * @return uint256 Number of whitelisted exchanges
     */
    function viewCountTransferAgentExchange() external view virtual returns (uint256) {
        return _whitelistedExchanges.length();
    }

    /**
     * @notice Retrieves all whitelisted transfer agent exchanges
     * @return addresses Array of all whitelisted exchange addresses
     * @dev For large lists, consider implementing pagination to avoid gas limits
     */
    function viewTransferAgentExchange() external view virtual returns (address[] memory addresses) {
        return _whitelistedExchanges.values();
    }

    uint256[9] private __gap;
}
