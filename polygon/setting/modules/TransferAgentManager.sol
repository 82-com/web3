// SPDX-License-Identifier: MIT
/// @title Transfer Agent Manager Contract  
/// @notice Abstract contract for managing whitelisted addresses (EOA or contracts) that can call asset transfer contracts  
/// @author Domain Team
pragma solidity ^0.8.22;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ITransferAgentManager} from "../interfaces/ITransferAgentManager.sol";

/// @title TransferAgentManager  
/// @notice Abstract contract that implements whitelist management for addresses authorized to call asset transfers  
/// @dev This contract maintains an EnumerableSet of whitelisted addresses (EOA or contracts) used by transfer contracts
abstract contract TransferAgentManager is ITransferAgentManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Storage slot constant for transfer agent exchanges storage
    bytes32 private constant TransferAgentExchangesStorageLocal = keccak256("domain.setting.transferAgent.exchanges");

    /// @notice Struct containing all transfer agent whitelist storage  
    /// @dev Uses EnumerableSet.AddressSet to efficiently manage and query whitelisted addresses
    struct TransferAgentExchangesStorage {
        EnumerableSet.AddressSet whitelistedExchanges;
    }

    /// @notice Gets the TransferAgentExchangesStorage from a predefined storage slot
    /// @return taes Reference to the TransferAgentExchangesStorage struct
    function _getTransferAgentExchangesStorage() private pure returns (TransferAgentExchangesStorage storage taes) {
        bytes32 slot = TransferAgentExchangesStorageLocal;
        assembly {
            taes.slot := slot
        }
    }

    /// @notice Checks if an exchange is whitelisted as a transfer agent
    /// @param exchange The address of the exchange to check
    /// @return bool True if exchange is whitelisted, false otherwise
    function isTransferAgentExchange(address exchange) public view virtual returns (bool) {
        return _getTransferAgentExchangesStorage().whitelistedExchanges.contains(exchange);
    }

    /// @notice Retrieves all whitelisted transfer agent exchanges
    /// @return addresses Array of all whitelisted exchange addresses
    /// @dev For large lists, consider implementing pagination to avoid gas limits
    function getTransferAgentExchangeSet() public view virtual returns (address[] memory addresses) {
        return _getTransferAgentExchangesStorage().whitelistedExchanges.values();
    }

    /// @notice Adds an address to the transfer agent whitelist  
    /// @param exchange The address (EOA or contract) to whitelist  
    /// @dev Requires TOKEN_MANAGER_ROLE to call  
    /// @custom:reverts InvalidExchangeAddress If address is zero  
    /// @custom:reverts ExchangeAlreadyWhitelisted If address is already whitelisted
    function _addTransferAgentExchange(address exchange) internal {
        if (exchange == address(0)) revert("Invalid exchange address");

        TransferAgentExchangesStorage storage taes = _getTransferAgentExchangesStorage();
        if (taes.whitelistedExchanges.contains(exchange)) revert("Exchange already whitelisted");
        taes.whitelistedExchanges.add(exchange);
        emit TransferAgentExchangeAdd(exchange);
    }

    /// @notice Removes an address from the transfer agent whitelist  
    /// @param exchange The address (EOA or contract) to remove  
    /// @dev Requires TOKEN_MANAGER_ROLE to call  
    /// @custom:reverts ExchangeNotWhitelisted If address is not in whitelist
    function _removeTransferAgentExchange(address exchange) internal {
        TransferAgentExchangesStorage storage taes = _getTransferAgentExchangesStorage();
        if (!taes.whitelistedExchanges.contains(exchange)) revert("Exchange not whitelisted");
        taes.whitelistedExchanges.remove(exchange);
        emit TransferAgentExchangeRemoved(exchange);
    }
}
