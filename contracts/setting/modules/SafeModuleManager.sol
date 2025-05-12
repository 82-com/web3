// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SettingERROR} from "./SettingERROR.sol";

abstract contract SafeModuleManager is SettingERROR {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ************************************
    // *           Storage               *
    // ************************************

    /// @dev Set of approved withdraw _moduleAddress
    EnumerableSet.AddressSet internal _safeModule;

    // ************************************
    // *           Events                *
    // ************************************

    /**
     * @notice Emitted when a _moduleAddress is added to the withdraw whitelist
     * @param _moduleAddress The address of the _moduleAddress that was added
     */
    event SafeModuleAdd(address _moduleAddress);

    /**
     * @notice Emitted when a _moduleAddress is removed from the withdraw whitelist
     * @param _moduleAddress The address of the _moduleAddress that was removed
     */
    event SafeModuleRemoved(address _moduleAddress);

    /**
     * @notice Adds a _moduleAddress wallet to the whitelist
     * @param _moduleAddress Address of the _moduleAddress wallet to whitelist
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If _moduleAddress already whitelisted
     */
    function _addSafeModule(address _moduleAddress) internal nonZeroAddress(_moduleAddress) {
        if (_safeModule.contains(_moduleAddress)) {
            revert AlreadyWhitelisted(_moduleAddress);
        }
        _safeModule.add(_moduleAddress);
        emit SafeModuleAdd(_moduleAddress);
    }

    /**
     * @notice Removes a _moduleAddress wallet from the whitelist
     * @param _moduleAddress Address of the _moduleAddress wallet to remove
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If _moduleAddress not in whitelist
     */
    function _removeSafeModule(address _moduleAddress) internal {
        if (!_safeModule.contains(_moduleAddress)) {
            revert NotWhitelisted(_moduleAddress);
        }
        _safeModule.remove(_moduleAddress);
        emit SafeModuleRemoved(_moduleAddress);
    }

    /**
     * @notice Checks if a _moduleAddress wallet is whitelisted
     * @param _moduleAddress Address of the _moduleAddress wallet to check
     * @return bool True if _moduleAddress is whitelisted
     */
    function isSafeModule(address _moduleAddress) external view virtual returns (bool) {
        return _safeModule.contains(_moduleAddress);
    }

    /**
     * @notice Gets the count of approved _moduleAddresss
     * @return uint256 Number of whitelisted _moduleAddresss
     */
    function viewCountSafeModule() external view virtual returns (uint256) {
        return _safeModule.length();
    }

    /**
     * @notice Retrieves all whitelisted withdraw _moduleAddresss
     * @return _moduleAddresss Array of all whitelisted _moduleAddress addresses
     * @dev For large lists, consider implementing pagination to avoid gas limits
     */
    function viewSafeModule() external view virtual returns (address[] memory _moduleAddresss) {
        return _safeModule.values();
    }

    uint256[9] private __gap;
}
