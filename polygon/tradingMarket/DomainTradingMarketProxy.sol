/// @title Domain Trading Market Proxy
/// @notice UUPS upgradeable proxy for DomainTradingMarketLogic
/// @author Domain Protocol Team
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Proxy contract for DomainTradingMarketLogic implementation
/// @dev Uses ERC1967 upgradeable proxy pattern
contract DomainTradingMarketProxy is ERC1967Proxy {
    /// @notice Initializes the proxy contract
    /// @param logic Address of the implementation contract
    /// @param _owner Address that will be the initial owner
    /// @param _settingManagerAddress Address of the settings manager contract
    /// @param _transferAgentAddress Address of the transfer agent contract
    constructor(
        address logic,
        address _owner,
        address _settingManagerAddress,
        address _transferAgentAddress
    )
        ERC1967Proxy(
            logic,
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                _owner,
                _settingManagerAddress,
                _transferAgentAddress
            )
        )
    {}
}
