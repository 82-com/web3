// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DomainNFTProxy is ERC1967Proxy {
    constructor(
        address logic,
        address admin,
        address freezeManager,
        address settingManager
    )
        ERC1967Proxy(
            logic,
            abi.encodeWithSignature("initialize(address,address,address)", admin, freezeManager, settingManager)
        )
    {}
}
