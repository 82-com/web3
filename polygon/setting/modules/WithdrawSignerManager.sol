// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title WithdrawSignerManager
 * @notice Module for managing whitelisted withdraw signers in the system
 * @dev Provides functionality to:
 * - Add/remove signer addresses from withdraw whitelist
 * - Check signer whitelist status
 * - View all whitelisted signers
 * - Manage signature threshold for multi-signature withdrawals
 * Uses EnumerableSet for efficient storage and retrieval
 * This contract integrates with multi-signature wallet withdrawal module
 */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IWithdrawSignerManager} from "../interfaces/IWithdrawSignerManager.sol";

abstract contract WithdrawSignerManager is IWithdrawSignerManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @dev Storage slot constant for withdraw signer data
     * Uses a unique hash to avoid storage collisions
     */
    bytes32 private constant WithdrawSignerStorageLocal = keccak256("domain.setting.signer.withdraw");

    /**
     * @dev Struct representing withdraw signer storage
     * @param signerSet Set of whitelisted signer addresses
     * @param threshold Minimum number of signatures required for withdrawal
     */
    struct WithdrawSignerStorage {
        EnumerableSet.AddressSet signerSet;
        uint256 threshold;
    }

    /**
     * @dev Returns the withdraw signer storage struct from a fixed slot
     * @return wss Reference to the withdraw signer storage struct
     */
    function _getWithdrawSignerStorage() private pure returns (WithdrawSignerStorage storage wss) {
        bytes32 slot = WithdrawSignerStorageLocal;
        assembly {
            wss.slot := slot
        }
    }

    /**
     * @notice Checks if a signer wallet is whitelisted
     * @param signer Address of the signer wallet to check
     * @return bool True if signer is whitelisted
     */
    function isWithdrawSigner(address signer) public view virtual returns (bool) {
        return _getWithdrawSignerStorage().signerSet.contains(signer);
    }

    /**
     * @notice Retrieves all whitelisted withdraw signers
     * @return signers Array of all whitelisted signer addresses
     * @dev For large lists, consider implementing pagination to avoid gas limits
     */
    function getWithdrawSignerSet() public view virtual returns (address[] memory signers) {
        return _getWithdrawSignerStorage().signerSet.values();
    }

    /**
     * @notice Gets the current signature threshold required for withdrawals
     * @return Current threshold value
     * @dev This value is used by multi-signature wallet to validate withdrawal requests
     */
    function getSignerThreshold() public view returns (uint256) {
        return _getWithdrawSignerStorage().threshold;
    }

    /**
     * @notice Adds a signer wallet to the whitelist
     * @param signer Address of the signer wallet to whitelist
     * @dev Only callable by SIGNER_MANAGER_ROLE
     */
    function _addWithdrawSigner(address signer) internal {
        if (signer == address(0)) revert("Invalid address");

        WithdrawSignerStorage storage wss = _getWithdrawSignerStorage();
        if (wss.signerSet.contains(signer)) revert("Signer already whitelisted");
        wss.signerSet.add(signer);
        emit WithdrawSignerAdd(signer); // Emitted when a new signer is added to whitelist
    }

    /**
     * @notice Removes a signer wallet from the whitelist
     * @param signer Address of the signer wallet to remove
     * @dev Only callable by SIGNER_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If signer not in whitelist
     */
    function _removeWithdrawSigner(address signer) internal {
        WithdrawSignerStorage storage wss = _getWithdrawSignerStorage();
        if (!wss.signerSet.contains(signer)) revert("Signer not whitelisted");
        wss.signerSet.remove(signer);
        emit WithdrawSignerRemoved(signer); // Emitted when a signer is removed from whitelist
    }

    /**
     * @notice Sets the threshold of signature required to withdraw
     * @param threshold The new threshold of signature required to withdraw
     * @dev Only callable by SIGNER_MANAGER_ROLE
     * @custom:reverts InvalidFeeRate If feeRate is greater than 100%
     */
    function _setSignerThreshold(uint256 threshold) internal {
        _getWithdrawSignerStorage().threshold = threshold;
        emit SignerThresholdChanged(threshold); // Emitted when signature threshold is updated
    }
}
