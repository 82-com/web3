// SPDX-License-Identifier: MIT

/// @title FragmentSwap Pair Proxy Contract
/// @notice Proxy contract for FragmentSwap pairs with upgradeable logic
/// @dev Inherits from ERC1967Proxy to provide upgradeability functionality

pragma solidity ^0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";

/// @title FragmentSwap Pair Proxy
/// @notice Proxy contract that delegates calls to upgradeable logic contracts
/// @dev Uses ERC1967 proxy pattern with dynamic logic address from Setting Manager
contract FragmentSwapPairProxy is ERC1967Proxy {
    /// @notice Address of the Setting Manager contract
    address public settingManager;

    /// @notice Constructs the FragmentSwapPairProxy
    /// @param logic Initial logic contract address
    /// @param _settingManager Address of the Setting Manager contract
    /// @dev Initializes the proxy with logic contract and Setting Manager
    constructor(address logic, address _settingManager) ERC1967Proxy(logic, "") {
        settingManager = _settingManager;
    }

    /// @notice Gets the current implementation address
    /// @dev Overrides ERC1967Proxy to get logic address dynamically from Setting Manager
    /// @return Address of the current logic contract
    function _implementation() internal view virtual override returns (address) {
        return IFractionManager(settingManager).getFragmentSwapPairLogic();
    }

    /// @notice Allows the contract to receive Ether
    /// @dev Required for the proxy to accept ETH transfers
    receive() external payable {}
}
