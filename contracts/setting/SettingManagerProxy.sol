// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title SettingManagerProxy
 * @dev Proxy contract for SettingManager system using ERC1967 upgradeable proxy pattern
 * This contract acts as a proxy that delegates all calls to an implementation contract
 * while preserving the storage layout for upgradeability
 */

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev SettingManagerProxy implements an upgradeable proxy pattern based on ERC1967 standard
 * The proxy delegates all calls to the implementation contract (logic) while maintaining
 * a consistent storage layout for upgradeability
 */
contract SettingManagerProxy is ERC1967Proxy {
    /**
     * @dev Initialize the upgradeable proxy
     * @param logic Address of the initial implementation contract
     * @param admin Address of the initial admin who can upgrade the implementation
     * @notice The proxy will immediately delegatecall to the logic contract's initialize function
     * with the admin address as parameter
     */
    constructor(
        address logic,
        address admin
    ) ERC1967Proxy(logic, abi.encodeWithSignature("initialize(address)", admin)) {}
}
