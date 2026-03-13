// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title TransferAgentProxy
 * @notice UUPS proxy implementation for TransferAgent contract
 * @dev This contract delegates all calls to an implementation contract while allowing upgrades
 */
contract TransferAgentProxy is ERC1967Proxy {
    /**
     * @dev Initializes the proxy with implementation contract and initialization data
     * @param logic Address of the implementation contract
     * @param _owner Address that will be the initial owner of the proxy
     * @param _settingManagerAddress Address of the setting manager contract
     */
    constructor(
        address logic,
        address _owner,
        address _settingManagerAddress
    ) ERC1967Proxy(logic, abi.encodeWithSignature("initialize(address,address)", _owner, _settingManagerAddress)) {}
}
