// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IDomainFraction} from "./interfaces/IDomainFraction.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";

/// @title Domain Fraction Proxy Contract
/// @notice ERC1967 proxy contract for Domain Fraction functionality
/// @dev This contract acts as a proxy that delegates calls to the implementation contract
contract DomainFractionProxy is ERC1967Proxy {
    /// @notice Address of the Setting Manager contract
    /// @dev Used to get the current implementation logic address
    address public settingManager;

    /// @notice Constructs the DomainFractionProxy contract
    /// @param logic Address of the initial implementation contract
    /// @param _settingManager Address of the Setting Manager contract
    /// @param _transferAgent Address of the Transfer Agent contract
    /// @param config ERC20 configuration parameters
    /// @param info ERC721 information parameters
    constructor(
        address logic,
        address _settingManager,
        address _transferAgent,
        IDomainFraction.ERC20Config memory config,
        IDomainFraction.ERC721Info memory info
    )
        ERC1967Proxy(
            logic,
            abi.encodeWithSignature(
                "initialize(address,address,(string,string,uint256,address),(address,uint256,address,uint256,uint256,uint256,uint256))",
                _settingManager,
                _transferAgent,
                config,
                info
            )
        )
    {
        settingManager = _settingManager;
    }

    /// @notice Returns the current implementation address
    /// @dev Overrides ERC1967Proxy._implementation() to get the logic address from Setting Manager
    /// @return Address of the current implementation contract
    function _implementation() internal view virtual override returns (address) {
        return IFractionManager(settingManager).getFragmentLogic();
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}
