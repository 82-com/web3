// SPDX-License-Identifier: MIT
/// @title Multi-Signature Wallet Manager Contract
/// @notice Abstract contract for managing multi-signature wallets and minters
/// @author Domain Team
pragma solidity ^0.8.22;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IMultiSignatureWalletManager} from "../interfaces/IMultiSignatureWalletManager.sol";

/// @title MultiSignatureWalletManager
/// @notice Abstract contract that implements multi-signature wallet management functionality
/// @dev This contract maintains whitelists of wallets and minters, and manages the wallet logic implementation
abstract contract MultiSignatureWalletManager is IMultiSignatureWalletManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Storage slot constant for multi-signature wallet storage
    bytes32 private constant MultiSignatureWalletStorageLocal = keccak256("domain.setting.wallet.whiteList");

    /// @notice Struct containing all multi-signature wallet related storage
    /// @dev This struct holds sets of whitelisted wallets and minters, plus the wallet logic implementation address
    struct MultiSignatureWalletStorage {
        EnumerableSet.AddressSet walletSet;
        EnumerableSet.AddressSet minterSet;
        address walletLogicAddress;
    }

    /// @notice Gets the MultiSignatureWalletStorage from a predefined storage slot
    /// @return msws Reference to the MultiSignatureWalletStorage struct
    function _getMultiSignatureWalletStorage() private pure returns (MultiSignatureWalletStorage storage msws) {
        bytes32 slot = MultiSignatureWalletStorageLocal;
        assembly {
            msws.slot := slot
        }
    }

    /// @notice Gets the current wallet logic implementation address
    /// @return address The address of the wallet logic implementation
    function getWalletLogic() public view returns (address) {
        return _getMultiSignatureWalletStorage().walletLogicAddress;
    }

    /// @notice Checks if an address is a whitelisted multi-signature wallet
    /// @param _walletAddress The address to check
    /// @return bool True if the address is whitelisted, false otherwise
    function isMultiSignatureWallet(address _walletAddress) public view virtual returns (bool) {
        return _getMultiSignatureWalletStorage().walletSet.contains(_walletAddress);
    }

    /// @notice Gets the number of whitelisted multi-signature wallets
    /// @return uint256 The count of whitelisted wallets
    function getMultiSignatureWalletSetLength() public view virtual returns (uint256) {
        return _getMultiSignatureWalletStorage().walletSet.length();
    }

    /// @notice Gets a paginated list of whitelisted multi-signature wallets
    /// @param offset The starting index for pagination
    /// @param limit The maximum number of items to return
    /// @return address[] Array of whitelisted wallet addresses
    function getMultiSignatureWalletSetPagination(
        uint256 offset,
        uint256 limit
    ) public view returns (address[] memory) {
        MultiSignatureWalletStorage storage msws = _getMultiSignatureWalletStorage();
        uint256 total = msws.walletSet.length();
        if (offset >= total) return new address[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = msws.walletSet.at(i);
        }
        return result;
    }

    /// @notice Gets all whitelisted wallet minters
    /// @return address[] Array of all minter addresses
    function getWalletMinter() public view virtual returns (address[] memory) {
        return _getMultiSignatureWalletStorage().minterSet.values();
    }

    /// @notice Checks if an address is a whitelisted wallet minter
    /// @param _minterAddress The address to check
    /// @return bool True if the address is a minter, false otherwise
    function isWalletMinter(address _minterAddress) public view virtual returns (bool) {
        return _getMultiSignatureWalletStorage().minterSet.contains(_minterAddress);
    }

    /// @notice Sets the wallet logic implementation address
    /// @param _implementation The address of the new wallet logic implementation
    function _setWalletLogic(address _implementation) internal {
        if (_implementation == address(0)) revert("Invalid wallet logic address");
        _getMultiSignatureWalletStorage().walletLogicAddress = _implementation;
        emit WalletLogicUpdated(_implementation);
    }

    /// @notice Adds a wallet to the whitelist
    /// @param _walletAddress The address of the wallet to whitelist
    /// @dev Only callable by SIGNER_MANAGER_ROLE
    /// @custom:reverts InvalidWalletAddress If _walletAddress is zero address
    /// @custom:reverts AlreadyWhitelisted If _walletAddress is already whitelisted
    function _addMultiSignatureWallet(address _walletAddress) internal {
        if (_walletAddress == address(0)) revert("Invalid wallet address");
        MultiSignatureWalletStorage storage msws = _getMultiSignatureWalletStorage();
        if (msws.walletSet.contains(_walletAddress)) {
            revert("Already whitelisted");
        }
        msws.walletSet.add(_walletAddress);
        emit MultiSignatureWalletAdd(_walletAddress);
    }

    /// @notice Removes a wallet from the whitelist
    /// @param _walletAddress The address of the wallet to remove
    /// @dev Only callable by SIGNER_MANAGER_ROLE
    /// @custom:reverts NotWhitelisted If _walletAddress is not in whitelist
    function _removeMultiSignatureWallet(address _walletAddress) internal {
        MultiSignatureWalletStorage storage msws = _getMultiSignatureWalletStorage();
        if (!msws.walletSet.contains(_walletAddress)) {
            revert("Not whitelisted");
        }
        msws.walletSet.remove(_walletAddress);
        emit MultiSignatureWalletRemoved(_walletAddress);
    }

    /// @notice Adds a minter to the whitelist
    /// @param _minterAddress The address of the minter to add
    /// @custom:reverts AlreadyMinter If _minterAddress is already a minter
    function _addWalletMinter(address _minterAddress) internal {
        MultiSignatureWalletStorage storage msws = _getMultiSignatureWalletStorage();
        if (msws.minterSet.contains(_minterAddress)) {
            revert("Already minter");
        }
        msws.minterSet.add(_minterAddress);
        emit MinterAdded(_minterAddress);
    }

    /// @notice Removes a minter from the whitelist
    /// @param _minterAddress The address of the minter to remove
    /// @custom:reverts NotMinter If _minterAddress is not a minter
    function _removeWalletMinter(address _minterAddress) internal {
        MultiSignatureWalletStorage storage msws = _getMultiSignatureWalletStorage();
        if (!msws.minterSet.contains(_minterAddress)) {
            revert("Not minter");
        }
        msws.minterSet.remove(_minterAddress);
        emit MinterRemoved(_minterAddress);
    }
}
