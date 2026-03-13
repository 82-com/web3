// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DomainExpenseProxy is ERC1967Proxy {
    constructor(
        address logic,
        address _admin,
        address _settingManagerAddress,
        address _transferAgentAddress
    )
        ERC1967Proxy(
            logic,
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                _admin,
                _settingManagerAddress,
                _transferAgentAddress
            )
        )
    {}
}
