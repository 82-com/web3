// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MultiSignatureWalletProxy} from "./MultiSignatureWalletProxy.sol";

import {IProxyFactory} from "./interfaces/IProxyFactory.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {IAdvancedContractFactory} from "./interfaces/IAdvancedContractFactory.sol";

/// @title Multi-Signature Wallet Proxy Factory
/// @notice Factory contract for creating and predicting multi-signature wallet proxy addresses
contract MultiSignatureWalletProxyFactory is IProxyFactory, Ownable {
    /// @notice Address of the Setting Manager contract
    address public immutable settingManager;
    
    /// @notice Address of the Transfer Agent contract
    address public immutable transferAgent;
    
    /// @notice Address of the Advanced Contract Factory
    address public immutable contractFactory;

    /// @notice Initializes the factory with required contract addresses
    /// @param initialOwner The owner of the factory contract
    /// @param initiaSettingManager Address of the Setting Manager contract
    /// @param initiaTransferAgent Address of the Transfer Agent contract
    /// @param initiaTContractFactory Address of the Advanced Contract Factory
    constructor(
        address initialOwner,
        address initiaSettingManager,
        address initiaTransferAgent,
        address initiaTContractFactory
    ) Ownable(initialOwner) {
        require(initiaSettingManager != address(0), "settingManager is zero address");
        require(initiaTransferAgent != address(0), "transferAgent is zero address");
        require(initiaTContractFactory != address(0), "tContractFactory is zero address");
        settingManager = initiaSettingManager;
        transferAgent = initiaTransferAgent;
        contractFactory = initiaTContractFactory;
    }

    /// @notice Modifier to restrict access to authorized minters only
    modifier onlyWalletMinter() {
        if (!IMultiSignatureWalletManager(settingManager).isWalletMinter(msg.sender)) {
            revert("only authorized minter");
        }
        _;
    }

    // ============ Proxy Creation Functions ============

    /// @notice Creates a new proxy wallet with specified parameters using a salt
    /// @dev Uses CREATE2 to deploy deterministic proxy addresses
    /// @param _owner The owner of the new proxy wallet
    /// @param _signers Array of signer addresses
    /// @param _threshold Minimum required signatures
    /// @param salt The salt value for deterministic deployment
    /// @return Address of the newly created proxy
    function createProxyWithSalt(
        address _owner,
        address[] memory _signers,
        uint256 _threshold,
        bytes32 salt
    ) external onlyWalletMinter returns (address) {
        address logicAddress = IMultiSignatureWalletManager(settingManager).getWalletLogic();
        bytes memory proxyBytecode = type(MultiSignatureWalletProxy).creationCode;
        bytes memory initData = abi.encode(
            logicAddress,
            address(this),
            settingManager,
            transferAgent,
            _owner,
            _signers,
            _threshold
        );
        address newProxy = IAdvancedContractFactory(contractFactory).createContractWithSalt(
            proxyBytecode,
            initData,
            salt
        );
        require(newProxy != address(0), "create proxy failure");
        emit ProxyCreated(newProxy, logicAddress, _owner, _signers, _threshold, salt);

        IMultiSignatureWalletManager(settingManager).addMultiSignatureWallet(newProxy);

        return newProxy;
    }

    /// @notice Predicts the address of a proxy wallet that would be created with given parameters
    /// @param _owner The owner of the proxy wallet
    /// @param _signers Array of signer addresses
    /// @param _threshold Minimum required signatures
    /// @param salt The salt value for deterministic deployment
    /// @return Predicted address of the proxy wallet
    function predictProxyAddressWithSalt(
        address _owner,
        address[] memory _signers,
        uint256 _threshold,
        bytes32 salt
    ) external view returns (address) {
        address logicAddress = IMultiSignatureWalletManager(settingManager).getWalletLogic();
        bytes memory proxyBytecode = type(MultiSignatureWalletProxy).creationCode;
        bytes memory initData = abi.encode(
            logicAddress,
            address(this),
            settingManager,
            transferAgent,
            _owner,
            _signers,
            _threshold
        );
        return IAdvancedContractFactory(contractFactory).computeAddress(proxyBytecode, initData, salt);
    }
}
