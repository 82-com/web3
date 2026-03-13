// SPDX-License-Identifier: MIT
/// @title Wallet Module Manager Contract
/// @notice Abstract contract for managing whitelisted wallet modules used by multi-signature wallets
/// @dev This contract maintains a set of approved modules that multi-sig wallets can verify
pragma solidity ^0.8.22;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IWalletModuleManager} from "../interfaces/IWalletModuleManager.sol";

/// @title WalletModuleManager
/// @notice Abstract contract that implements wallet module management functionality
/// @dev Used by multi-signature wallets to verify if a module is approved
abstract contract WalletModuleManager is IWalletModuleManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Storage slot constant for wallet module storage
    bytes32 private constant WalletModuleStorageLocal = keccak256("domain.setting.wallet.module");

    /// @notice Struct containing all wallet module related storage
    /// @dev Uses EnumerableSet.AddressSet to efficiently manage approved modules
    struct WalletModuleStorage {
        EnumerableSet.AddressSet moduleSet;
    }

    /// @notice Gets the WalletModuleStorage from a predefined storage slot
    /// @return ms Reference to the WalletModuleStorage struct
    function _getWalletModuleStorage() private pure returns (WalletModuleStorage storage ms) {
        bytes32 slot = WalletModuleStorageLocal;
        assembly {
            ms.slot := slot
        }
    }

    /// @notice Checks if a module is approved for use by multi-signature wallets
    /// @param _moduleAddress The address of the module to check
    /// @return bool True if module is approved, false otherwise
    function isWalletModule(address _moduleAddress) public view virtual returns (bool) {
        return _getWalletModuleStorage().moduleSet.contains(_moduleAddress);
    }

    /// @notice Gets the number of approved wallet modules
    /// @return uint256 Count of approved modules
    function getWalletModuleSetLength() public view virtual returns (uint256) {
        return _getWalletModuleStorage().moduleSet.length();
    }

    /// @notice Retrieves all approved wallet modules
    /// @return _moduleAddresss Array of all approved module addresses
    /// @dev For large lists, consider implementing pagination to avoid gas limits
    function getWalletModuleSet() public view virtual returns (address[] memory _moduleAddresss) {
        return _getWalletModuleStorage().moduleSet.values();
    }

    /// @notice Adds a wallet module to the approved set
    /// @param _moduleAddress The address of the module to approve
    /// @dev Requires SIGNER_MANAGER_ROLE to call
    /// @custom:reverts InvalidModuleAddress If module address is zero
    /// @custom:reverts AlreadyWhitelisted If module is already approved
    function _addWalletModule(address _moduleAddress) internal {
        if (_moduleAddress == address(0)) revert("Invalid module address");
        WalletModuleStorage storage ms = _getWalletModuleStorage();
        if (ms.moduleSet.contains(_moduleAddress)) {
            revert("Already whitelisted");
        }
        ms.moduleSet.add(_moduleAddress);
        emit WalletModuleAdd(_moduleAddress);
    }

    /// @notice Removes a wallet module from the approved set
    /// @param _moduleAddress The address of the module to remove
    /// @dev Requires SIGNER_MANAGER_ROLE to call
    /// @custom:reverts NotWhitelisted If module is not in approved set
    function _removeWalletModule(address _moduleAddress) internal {
        WalletModuleStorage storage ms = _getWalletModuleStorage();
        if (!ms.moduleSet.contains(_moduleAddress)) {
            revert("Not whitelisted");
        }
        ms.moduleSet.remove(_moduleAddress);
        emit WalletModuleRemoved(_moduleAddress);
    }
}
