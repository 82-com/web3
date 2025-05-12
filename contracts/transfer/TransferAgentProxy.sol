// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TransferAgentProxy is ERC1967Proxy {
    constructor(
        address logic,
        address _owner,
        address _settingManagerAddress
    ) ERC1967Proxy(logic, abi.encodeWithSignature("initialize(address,address)", _owner, _settingManagerAddress)) {}
}
