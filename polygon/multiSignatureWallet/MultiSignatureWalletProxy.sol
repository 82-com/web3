// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";

/// @title Multi-Signature Wallet Proxy Contract
/// @notice ERC1967 proxy implementation for multi-signature wallets with dynamic logic contract address
contract MultiSignatureWalletProxy is ERC1967Proxy {
    /// @notice Address of the Setting Manager contract
    address public settingManager;

    /// @notice Initializes the proxy contract
    /// @param logic Initial logic contract address
    /// @param _factory Address of the proxy factory
    /// @param _settingManager Address of the Setting Manager contract
    /// @param _transferAgent Address of the Transfer Agent contract
    /// @param _owner Owner address of the proxy
    /// @param _signers Array of initial signer addresses
    /// @param _threshold Minimum required signatures threshold
    constructor(
        address logic,
        address _factory,
        address _settingManager,
        address _transferAgent,
        address _owner,
        address[] memory _signers,
        uint256 _threshold
    )
        ERC1967Proxy(
            logic,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address[],uint256)",
                _factory,
                _settingManager,
                _transferAgent,
                _owner,
                _signers,
                _threshold
            )
        )
    {
        settingManager = _settingManager;
    }

    /// @notice Gets the current implementation address from Setting Manager
    /// @dev Overrides ERC1967Proxy's implementation getter to provide dynamic logic contract address
    /// @return Address of the current logic contract
    function _implementation() internal view virtual override returns (address) {
        return IMultiSignatureWalletManager(settingManager).getWalletLogic();
    }

    /// @notice Allows the contract to receive Ether
    /// @dev Required for the proxy to receive ETH transfers
    receive() external payable {}
}
