// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title SafeProxyManager
 * @notice Module for managing whitelisted Safe proxy wallets in the system
 * @dev Provides functionality to:
 * - Add/remove Safe wallets from whitelist
 * - Check whitelist status
 * - Paginated view of all whitelisted Safes
 * Uses EnumerableSet for efficient storage and retrieval
 */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SettingERROR} from "./SettingERROR.sol";

abstract contract SafeProxyManager is SettingERROR {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ************************************
    // *           Storage               *
    // ************************************

    /// @dev Set of approved safe wallets
    EnumerableSet.AddressSet internal _whitelistedSafes;

    // ************************************
    // *           Events                *
    // ************************************

    /**
     * @notice Emitted when a Safe proxy is added to the whitelist
     * @param safe The address of the Safe proxy that was added
     */
    event SafeProxyAdd(address safe);

    /**
     * @notice Emitted when a Safe proxy is removed from the whitelist
     * @param safe The address of the Safe proxy that was removed
     */
    event SafeProxyRemoved(address safe);

    /**
     * @notice Adds a safe wallet to the whitelist
     * @param safe Address of the safe wallet to whitelist
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If safe already whitelisted
     */
    function _addSafeProxy(address safe) internal nonZeroAddress(safe) {
        if (_whitelistedSafes.contains(safe)) {
            revert AlreadyWhitelisted(safe);
        }
        _whitelistedSafes.add(safe);
        emit SafeProxyAdd(safe);
    }

    /**
     * @notice Removes a safe wallet from the whitelist
     * @param safe Address of the safe wallet to remove
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If safe not in whitelist
     */
    function _removeSafeProxy(address safe) internal {
        if (!_whitelistedSafes.contains(safe)) {
            revert NotWhitelisted(safe);
        }
        _whitelistedSafes.remove(safe);
        emit SafeProxyRemoved(safe);
    }

    /**
     * @notice Checks if a safe wallet is whitelisted
     * @param safe Address of the safe wallet to check
     * @return bool True if safe is whitelisted
     */
    function _isSafeWhitelisted(address safe) internal view returns (bool) {
        return _whitelistedSafes.contains(safe);
    }

    /**
     * @notice Checks if a safe wallet is whitelisted
     * @param safe Address of the safe wallet to check
     * @return bool True if safe is whitelisted
     */
    function isSafeWhitelisted(address safe) external view virtual returns (bool) {
        return _isSafeWhitelisted(safe);
    }

    /**
     * @notice Gets the count of approved safes
     * @return uint256 Number of whitelisted safes
     */
    function viewCountWhitelistedSafes() external view virtual returns (uint256) {
        return _whitelistedSafes.length();
    }

    /**
     * @notice Retrieves a paginated list of whitelisted safes
     * @param cursor The starting index for pagination (0 for the first page)
     * @param size The number of items to retrieve per page (max 100 recommended)
     * @return whitelistedSafes An array of whitelisted safe addresses
     * @return newCursor The updated cursor for the next page
     * @dev Pagination pattern similar to OpenZeppelin's EnumerableSet
     * @custom:reverts InvalidPagination If cursor is out of bounds
     */
    function viewWhitelistedSafes(
        uint256 cursor,
        uint256 size
    ) external view virtual returns (address[] memory whitelistedSafes, uint256 newCursor) {
        uint256 totalItems = _whitelistedSafes.length();
        uint256 length = size > (totalItems - cursor) ? (totalItems - cursor) : size;

        address[] memory safes = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            safes[i] = _whitelistedSafes.at(cursor + i);
        }

        return (safes, cursor + length);
    }

    uint256[9] private __gap;
}
