// SPDX-License-Identifier: MIT
/// @title MultiSignatureWalletLogic - Smart contract for multi-signature wallet functionality
/// @author Domain Team
/// @notice This contract implements core logic for a multi-signature wallet with module support
/// @dev Inherits from multiple OpenZeppelin contracts and implements custom validation logic
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {MultiSignatureValidator} from "./MultiSignatureValidator.sol";
import {ERC721Receiver} from "./ERC721Receiver.sol";

import {IDomainNFT} from "../domainNft/interfaces/IDomainNFT.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {IWalletModuleManager} from "../setting/interfaces/IWalletModuleManager.sol";
import {ITokenManager} from "../setting/interfaces/ITokenManager.sol";
import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";
import {IVerifySignatures} from "./interfaces/IVerifySignatures.sol";
import {IMultiSignatureWalletLogic} from "./interfaces/IMultiSignatureWalletLogic.sol";
import {IProxyFactory} from "./interfaces/IProxyFactory.sol";

/// @notice Main contract implementing multi-signature wallet logic with module support
/// @dev Combines EIP712 for typed data signing, Ownable for ownership control,
///      MultiSignatureValidator for signature validation, and ReentrancyGuard for security
contract MultiSignatureWalletLogic is
    IMultiSignatureWalletLogic,
    EIP712,
    OwnableUpgradeable,
    MultiSignatureValidator,
    ReentrancyGuard,
    ERC721Receiver
{
    using ECDSA for bytes32;

    /// @notice Current version of the contract
    /// @dev Used for upgradeability tracking
    uint256 public constant VERSIONS = 1;

    bytes4 constant MINT_SELECTOR = IDomainNFT.batchMintById.selector;
    bytes4 constant BURN_SELECTOR = IDomainNFT.batchBurn.selector;
    bytes4 constant TRANSFER_SELECTOR = IERC20.transfer.selector;
    bytes4 constant APPROVE_SELECTOR = IERC20.approve.selector;

    /// @notice Type hash for transaction execution
    /// @dev Used in EIP712 typed data signing
    bytes32 private constant _TRANSACTION_TYPEHASH =
        keccak256("ExecTransaction(address to,uint256 value,bytes data,uint256 parallelNonce)");

    /// @notice Type hash for module execution
    /// @dev Used in EIP712 typed data signing
    bytes32 private constant _MODULE_TYPEHASH =
        keccak256("ExecModule(address module,bytes data,uint256 parallelNonce)");

    /// @notice Storage slot for wallet data
    /// @dev Uses a unique keccak256 hash to avoid storage collisions
    bytes32 private constant WalletStorageLocal = keccak256("domain.wallet.logic");

    /// @notice Wallet storage structure
    /// @dev Contains wallet configuration and state
    struct WalletStorage {
        /// @dev Address of the factory contract
        address factory;
        /// @dev Address of the setting manager contract
        address settingManager;
        /// @dev Address of the transfer agent contract
        address transferAgent;
        /// @dev Tracks used nonces to prevent replay attacks
        mapping(uint256 => bool) usedNonces;
    }

    /// @notice Gets the wallet storage struct from storage
    /// @dev Uses assembly to access storage slot
    /// @return ws Reference to the WalletStorage struct
    function _getWalletStorage() private pure returns (WalletStorage storage ws) {
        bytes32 slot = WalletStorageLocal;
        assembly {
            ws.slot := slot
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Constructor that disables initializers
    /// @dev Sets up EIP712 domain separator
    constructor() EIP712("MultiSignatureWallet", "1") {
        _disableInitializers();
    }

    /// @notice Emitted when wallet logic is updated
    /// @param newImplementation Address of the new logic implementation
    event SyncLogic(address newImplementation);

    /// @notice Emitted when a transaction is successfully executed
    /// @param txhash Hash of the executed transaction
    /// @param usedNonces The nonce that was used for the transaction
    event ExecutionSuccess(bytes32 txhash, uint256 usedNonces);

    /// @notice Modifier to ensure deadline has not passed
    /// @param deadline Timestamp to check against current block time
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "Deadline passed");
        _;
    }

    /// @notice Initializes the wallet contract
    /// @dev Sets up initial configuration and ownership
    /// @param factory Address of the factory contract
    /// @param settingManager Address of the setting manager contract
    /// @param transferAgent Address of the transfer agent contract
    /// @param initialOwner Address of the initial owner
    /// @param initialSigners Array of initial signer addresses
    /// @param initialThreshold Minimum number of signatures required
    function initialize(
        address factory,
        address settingManager,
        address transferAgent,
        address initialOwner,
        address[] calldata initialSigners,
        uint256 initialThreshold
    ) external initializer {
        __Ownable_init(initialOwner);
        __MultiSignatureValidator_init(initialSigners, initialThreshold);

        WalletStorage storage ws = _getWalletStorage();
        ws.factory = factory;
        ws.settingManager = settingManager;
        ws.transferAgent = transferAgent;
        authorizedSecureERC20();
        authorizedSecureERC721();
    }

    /// @notice Gets the initial configuration of the wallet
    /// @return factory Address of the factory contract
    /// @return settingManager Address of the setting manager contract
    /// @return transferAgent Address of the transfer agent contract
    function getInitialConfiguration() external view returns (address, address, address) {
        WalletStorage storage ws = _getWalletStorage();
        return (ws.factory, ws.settingManager, ws.transferAgent);
    }

    /// @notice Adds a new signer to the wallet
    /// @dev Can only be called by the owner
    /// @param signer Address of the signer to add
    function addSigner(address signer) external onlyOwner {
        _addSigner(signer);
    }

    /// @notice Removes a signer from the wallet
    /// @dev Can only be called by the owner
    /// @param signer Address of the signer to remove
    function removeSigner(address signer) external onlyOwner {
        _removeSigner(signer);
    }

    /// @notice Sets the threshold for required signatures
    /// @dev Can only be called by the owner
    /// @param newThreshold New threshold value
    function setThreshold(uint256 newThreshold) external onlyOwner {
        _setThreshold(newThreshold);
    }

    /// @notice Executes a transaction with multiple signatures
    /// @dev Supports parallel nonces to allow out-of-order execution
    /// @param to Destination address of the transaction
    /// @param value Ether value to send
    /// @param data Transaction data
    /// @param parallelNonce Nonce to prevent replay attacks
    /// @param signatures Array of signatures
    /// @param deadline Deadline for the transaction
    function executeTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 parallelNonce,
        bytes[] calldata signatures,
        uint256 deadline
    ) external payable nonReentrant ensure(deadline) {
        if (data.length >= 4) {
            address settingManager = _getWalletStorage().settingManager;
            bytes4 selector = bytes4(data[0:4]);
            if (
                ITokenManager(settingManager).isTokenWhitelisted(to) && selector != MINT_SELECTOR && selector != BURN_SELECTOR
            ) revert("Unallowed");
        }
        require(signatures.length >= getThreshold(), "Insufficient signatures");

        // Verify signatures (using parallel nonce)
        bytes32 txHash = getTransactionHash(to, value, data, parallelNonce);
        if (!verifySignatures(txHash, signatures)) revert("Invalid or insufficient signatures");
        _markNonceUsed(parallelNonce);

        // Execute transaction
        _executeCall(to, value, data);
        emit ExecutionSuccess(txHash, parallelNonce);
    }

    /// @notice Executes a module transaction with multiple signatures
    /// @dev Uses delegatecall to execute module functionality
    /// @param module Address of the module to execute
    /// @param data Transaction data for the module
    /// @param parallelNonce Nonce to prevent replay attacks
    /// @param signatures Array of signatures
    /// @param deadline Deadline for the transaction
    function executeModuleTransaction(
        address module,
        bytes calldata data,
        uint256 parallelNonce,
        bytes[] calldata signatures,
        uint256 deadline
    ) external nonReentrant ensure(deadline) {
        require(
            IWalletModuleManager(_getWalletStorage().settingManager).isWalletModule(module),
            "Module not authorized"
        );
        require(signatures.length >= getThreshold(), "Insufficient signatures");

        // Verify signatures (using parallel nonce)
        bytes32 txHash = getModuleHash(module, data, parallelNonce);
        // Each module may have different signature verification rules
        if (!IVerifySignatures(module).verifySignatures(txHash, signatures)) {
            revert("Invalid or insufficient signatures");
        }
        _markNonceUsed(parallelNonce);

        // Use delegatecall to execute module
        (bool success, ) = module.delegatecall(data);
        require(success, "Module call failed");
        emit ExecutionSuccess(txHash, parallelNonce);
    }

    /// @notice Authorizes ERC20 token transfers to the transfer agent
    /// @dev Approves max uint256 allowance for all whitelisted ERC20 tokens
    function authorizedSecureERC20() public {
        WalletStorage storage ws = _getWalletStorage();
        address[] memory erc20List = ITokenManager(ws.settingManager).getWhitelistedTokensByType(
            ITokenManager.TokenType.ERC20
        );
        for (uint256 i = 0; i < erc20List.length; i++) {
            if (IERC20(erc20List[i]).allowance(address(this), ws.transferAgent) == 0) {
                IERC20(erc20List[i]).approve(ws.transferAgent, type(uint256).max);
            }
        }
    }

    /// @notice Authorizes ERC721 token transfers to the transfer agent
    /// @dev Sets approval for all for all whitelisted ERC721 tokens
    function authorizedSecureERC721() public {
        WalletStorage storage ws = _getWalletStorage();
        address[] memory erc721List = ITokenManager(ws.settingManager).getWhitelistedTokensByType(
            ITokenManager.TokenType.ERC721
        );
        for (uint256 i = 0; i < erc721List.length; i++) {
            if (IERC721(erc721List[i]).isApprovedForAll(address(this), ws.transferAgent) == false) {
                IERC721(erc721List[i]).setApprovalForAll(ws.transferAgent, true);
            }
        }
    }

    /// @notice Syncs the wallet logic implementation
    /// @dev Updates the proxy implementation slot to point to the latest logic
    function syncLogic() external {
        // Get latest logic address
        address newLogic = IMultiSignatureWalletManager(_getWalletStorage().settingManager).getWalletLogic();
        require(newLogic != address(0), "Invalid new logic");

        // Update proxy implementation slot (ERC1967 slot)
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        assembly {
            sstore(implementationSlot, newLogic)
        }
        emit SyncLogic(newLogic);
    }

    /// @notice Checks if a nonce has been used
    /// @param parallelNonce The nonce to check
    /// @return True if the nonce has been used, false otherwise
    function isNonceUsed(uint256 parallelNonce) public view returns (bool) {
        return _getWalletStorage().usedNonces[parallelNonce];
    }

    /// @notice Gets the hash for a transaction
    /// @dev Uses EIP712 typed data hashing
    /// @param to Destination address
    /// @param value Ether value
    /// @param data Transaction data
    /// @param parallelNonce Nonce for the transaction
    /// @return The EIP712 hash of the transaction
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 parallelNonce
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(_TRANSACTION_TYPEHASH, to, value, keccak256(data), parallelNonce)));
    }

    /// @notice Gets the hash for a module transaction
    /// @dev Uses EIP712 typed data hashing
    /// @param module Module address
    /// @param data Transaction data
    /// @param parallelNonce Nonce for the transaction
    /// @return The EIP712 hash of the module transaction
    function getModuleHash(address module, bytes calldata data, uint256 parallelNonce) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(_MODULE_TYPEHASH, module, keccak256(data), parallelNonce)));
    }

    /// @dev Marks a nonce as used to prevent replay attacks
    /// @param parallelNonce The nonce to mark as used
    function _markNonceUsed(uint256 parallelNonce) private {
        WalletStorage storage ws = _getWalletStorage();
        require(!ws.usedNonces[parallelNonce], "Nonce already used");
        ws.usedNonces[parallelNonce] = true;
    }

    /// @dev Executes a low-level call
    /// @param to Target address
    /// @param value Ether value
    /// @param data Call data
    function _executeCall(address to, uint256 value, bytes memory data) private {
        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!success) {
            if (result.length == 0) revert("Transaction failed");
            assembly {
                revert(add(32, result), mload(result))
            }
        }
    }

    /// @notice Fallback function to receive Ether
    receive() external payable {}
}
