// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title WithdrawSignerManager
 * @notice Module for managing whitelisted withdraw signers in the system
 * @dev Provides functionality to:
 * - Add/remove signer addresses from withdraw whitelist
 * - Check signer whitelist status
 * - View all whitelisted signers
 * Uses EnumerableSet for efficient storage and retrieval
 */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SettingERROR} from "./SettingERROR.sol";

abstract contract WithdrawSignerManager is SettingERROR {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ************************************
    // *           Storage               *
    // ************************************

    /// @dev Set of approved withdraw signer
    EnumerableSet.AddressSet internal _withdrawSigner;

    // ************************************
    // *           Events                *
    // ************************************

    /**
     * @notice Emitted when a signer is added to the withdraw whitelist
     * @param signer The address of the signer that was added
     */
    event WithdrawSignerAdd(address signer);

    /**
     * @notice Emitted when a signer is removed from the withdraw whitelist
     * @param signer The address of the signer that was removed
     */
    event WithdrawSignerRemoved(address signer);

    /**
     * @notice Adds a signer wallet to the whitelist
     * @param signer Address of the signer wallet to whitelist
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If signer already whitelisted
     */
    function _addWithdrawSigner(address signer) internal nonZeroAddress(signer) {
        if (_withdrawSigner.contains(signer)) {
            revert AlreadyWhitelisted(signer);
        }
        _withdrawSigner.add(signer);
        emit WithdrawSignerAdd(signer);
    }

    /**
     * @notice Removes a signer wallet from the whitelist
     * @param signer Address of the signer wallet to remove
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If signer not in whitelist
     */
    function _removeWithdrawSigner(address signer) internal {
        if (!_withdrawSigner.contains(signer)) {
            revert NotWhitelisted(signer);
        }
        _withdrawSigner.remove(signer);
        emit WithdrawSignerRemoved(signer);
    }

    /**
     * @notice Checks if a signer wallet is whitelisted
     * @param signer Address of the signer wallet to check
     * @return bool True if signer is whitelisted
     */
    function isWithdrawSigner(address signer) external view virtual returns (bool) {
        return _withdrawSigner.contains(signer);
    }

    /**
     * @notice Gets the count of approved signers
     * @return uint256 Number of whitelisted signers
     */
    function viewCountWithdrawSigner() external view virtual returns (uint256) {
        return _withdrawSigner.length();
    }

    /**
     * @notice Retrieves all whitelisted withdraw signers
     * @return signers Array of all whitelisted signer addresses
     * @dev For large lists, consider implementing pagination to avoid gas limits
     */
    function viewWithdrawSigner() external view virtual returns (address[] memory signers) {
        return _withdrawSigner.values();
    }

    uint256[9] private __gap;
}
