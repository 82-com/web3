// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

import {FeesManager} from "./modules/FeesManager.sol";
import {FractionManager} from "./modules/FractionManager.sol";
import {WalletModuleManager} from "./modules/WalletModuleManager.sol";
import {MultiSignatureWalletManager} from "./modules/MultiSignatureWalletManager.sol";
import {TokenManager} from "./modules/TokenManager.sol";
import {TransferAgentManager} from "./modules/TransferAgentManager.sol";
import {WithdrawSignerManager} from "./modules/WithdrawSignerManager.sol";

/**
 * @title SettingManagerLogic
 * @notice Central configuration manager for domain exchange system with:
 * - Token whitelisting and management (ERC20/ERC721/ERC1155)
 * - Safe proxy wallet management
 * - Transaction and royalty fee configuration
 * - Withdrawal signer management
 * - Transfer agent management
 * - Fractional ownership management
 * @dev Uses UUPS upgradeable pattern with role-based access control
 * Inherits functionality from multiple manager modules:
 * - FeesManager: Fee configuration
 * - FractionManager: Fractional ownership settings
 * - WalletModuleManager: Wallet module management
 * - MultiSignatureWalletManager: Multi-sig wallet management
 * - TokenManager: Token whitelisting
 * - TransferAgentManager: Transfer agent configuration
 * - WithdrawSignerManager: Withdrawal authorization
 */
contract SettingManagerLogic is
    FeesManager,
    FractionManager,
    WalletModuleManager,
    MultiSignatureWalletManager,
    TokenManager,
    TransferAgentManager,
    WithdrawSignerManager,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    // ************************************
    // *           Storage               *
    // ************************************

    /**
     * @notice Current version of the contract
     * @dev Used for upgrade compatibility checks
     */
    uint256 public constant VERSION = 2;

    /**
     * @notice Role for managing fee configurations
     * @dev Granted to fee administrators
     */
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    /**
     * @notice Role for managing token whitelisting
     * @dev Granted to token administrators
     */
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");

    /**
     * @notice Role for managing multi-signature wallets
     * @dev Granted to safe administrators
     */
    bytes32 public constant SAFE_MANAGER_ROLE = keccak256("SAFE_MANAGER_ROLE");

    /**
     * @notice Role for managing withdrawal signers
     * @dev Granted to signer administrators
     */
    bytes32 public constant SIGNER_MANAGER_ROLE = keccak256("SIGNER_MANAGER_ROLE");

    /**
     * @notice Role for managing fractional ownership settings
     * @dev Granted to fraction administrators
     */
    bytes32 public constant FRACTION_MANAGER_ROLE = keccak256("FRACTION_MANAGER_ROLE");

    // ************************************
    // *       Constructor & Init        *
    // ************************************

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     * @dev Disables initializers to prevent direct initialization after deployment
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with default admin roles
     * @dev Sets up initial access control and inherited contracts
     * @param _admin The address to be granted default admin roles
     */
    function initialize(address _admin) public virtual initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(TOKEN_MANAGER_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
        _grantRole(SIGNER_MANAGER_ROLE, _admin);

        __FeesManager_init(_admin);
        __FractionManager_init(_admin);
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Restricts upgrade authorization to DEFAULT_ADMIN_ROLE
     * @param _newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ************************************
    // *      Fee Management              *
    // ************************************

    /**
     * @notice Configures market fee rates and receivers
     * @dev Only callable by FEE_MANAGER_ROLE
     * @param _transactionFeeReceiver Address receiving transaction fees
     * @param _transactionFeeRate Basis points for transaction fee (10000 = 1%)
     * @param _nftCreatorFirstRoyaltyRate Basis points for first sale royalty
     * @param _nftCreatorRoyaltyRate Basis points for secondary sale royalty
     * @param _buyerInviterRoyaltyRate Basis points for buyer inviter reward
     * @param _sellerInviterRoyaltyRate Basis points for seller inviter reward
     */
    function setMarketFees(
        address _transactionFeeReceiver,
        uint32 _transactionFeeRate,
        uint32 _nftCreatorFirstRoyaltyRate,
        uint32 _nftCreatorRoyaltyRate,
        uint32 _buyerInviterRoyaltyRate,
        uint32 _sellerInviterRoyaltyRate
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setMarketFees(
            _transactionFeeReceiver,
            _transactionFeeRate,
            _nftCreatorFirstRoyaltyRate,
            _nftCreatorRoyaltyRate,
            _buyerInviterRoyaltyRate,
            _sellerInviterRoyaltyRate
        );
    }

    /**
     * @notice Configures swap fee rates and receiver
     * @dev Only callable by FEE_MANAGER_ROLE
     * @param _swapFeeReceiver Address receiving swap fees
     * @param _swapFee Basis points for swap fee (10000 = 1%)
     * @param _swapLpFee Basis points for LP portion of swap fee
     */
    function setSwapFees(
        address _swapFeeReceiver,
        uint32 _swapFee,
        uint32 _swapLpFee
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setSwapFees(_swapFeeReceiver, _swapFee, _swapLpFee);
    }

    /**
     * @notice Configures order book fee rates and receiver
     * @dev Only callable by FEE_MANAGER_ROLE
     * @param _orderBookFeeReceiver Address receiving order book fees
     * @param _makerFee Basis points for maker fee (10000 = 1%)
     * @param _takerFee Basis points for taker fee (10000 = 1%)
     */
    function setOrderBookFees(
        address _orderBookFeeReceiver,
        uint32 _makerFee,
        uint32 _takerFee
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setOrderBookFees(_orderBookFeeReceiver, _makerFee, _takerFee);
    }

    /**
     * @notice Sets the withdrawal fee receiver address
     * @dev Only callable by FEE_MANAGER_ROLE
     * @param _withdrawalFeeReceiver Address receiving withdrawal fees
     */
    function setWithdrawalFeeReceiver(address _withdrawalFeeReceiver) external onlyRole(FEE_MANAGER_ROLE) {
        _setWithdrawalFeeReceiver(_withdrawalFeeReceiver);
    }

    /**
     * @notice Sets the domain expense receiver address
     * @dev Only callable by FEE_MANAGER_ROLE
     * @param _domainExpenseReceiver Address receiving domain expenses
     */
    function setDomainExpenseReceiver(address _domainExpenseReceiver) external onlyRole(FEE_MANAGER_ROLE) {
        _setDomainExpenseReceiver(_domainExpenseReceiver);
    }

    // ************************************
    // *    Fraction Config Management      *
    // ************************************

    function setFractionConfig(
        uint32 _minVoteDuration,
        uint32 _maxVoteDuration,
        uint32 _votePercentage,
        uint32 _minAuctionDuration,
        uint32 _maxAuctionDuration,
        uint32 _bidIncreasePercentage,
        uint32 _serviceCharge,
        address _serviceChargeReceiver
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setFractionConfig(
            _minVoteDuration,
            _maxVoteDuration,
            _votePercentage,
            _minAuctionDuration,
            _maxAuctionDuration,
            _bidIncreasePercentage,
            _serviceCharge,
            _serviceChargeReceiver
        );
    }

    function setFragmentLogic(address _implementation) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setFragmentLogic(_implementation);
    }

    function setFragmentSwapPairLogic(address _implementation) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setFragmentSwapPairLogic(_implementation);
    }

    function addFragmentContract(address _contract) external onlyRole(FRACTION_MANAGER_ROLE) {
        _addFragmentContract(_contract);
    }

    function removeFragmentContract(address _contract) external onlyRole(FRACTION_MANAGER_ROLE) {
        _removeFragmentContract(_contract);
    }

    // ************************************
    // *      Token Management            *
    // ************************************

    function addToken(address _token, TokenType _tokenType) external onlyRole(TOKEN_MANAGER_ROLE) {
        _addToken(_token, _tokenType);
    }

    function removeToken(address _token) external onlyRole(TOKEN_MANAGER_ROLE) {
        _removeToken(_token);
    }

    // ************************************
    // *   transfer agent Management      *
    // ************************************

    function addTransferAgentExchange(address _exchange) external onlyRole(TOKEN_MANAGER_ROLE) {
        _addTransferAgentExchange(_exchange);
    }

    function removeTransferAgentExchange(address _exchange) external onlyRole(TOKEN_MANAGER_ROLE) {
        _removeTransferAgentExchange(_exchange);
    }

    // ************************************
    // *    wallet Proxy Management       *
    // ************************************

    function setWalletLogic(address _implementation) external onlyRole(SIGNER_MANAGER_ROLE) {
        _setWalletLogic(_implementation);
    }

    function addWalletMinter(address _minterAddress) external onlyRole(SIGNER_MANAGER_ROLE) {
        _addWalletMinter(_minterAddress);
    }

    function removeWalletMinter(address _minterAddress) external onlyRole(SIGNER_MANAGER_ROLE) {
        _removeWalletMinter(_minterAddress);
    }

    function addMultiSignatureWallet(address _walletAddress) external onlyRole(SAFE_MANAGER_ROLE) {
        _addMultiSignatureWallet(_walletAddress);
    }

    function removeMultiSignatureWallet(address _walletAddress) external onlyRole(SAFE_MANAGER_ROLE) {
        _removeMultiSignatureWallet(_walletAddress);
    }

    function isSafeReceiver(address _address) external view override returns (bool) {
        return
            super.isMultiSignatureWallet(_address) ||
            _address == getMarketFeesStruct().transactionFeeReceiver ||
            _address == getSwapFeesStruct().swapFeeReceiver ||
            _address == getWithdrawalFeeReceiver() ||
            _address == getDomainExpenseReceiver();
    }

    // ************************************
    // *   withdraw signer Management     *
    // ************************************

    function addWithdrawSigner(address _signer) external onlyRole(SIGNER_MANAGER_ROLE) {
        _addWithdrawSigner(_signer);
    }

    function removeWithdrawSigner(address _signer) external onlyRole(SIGNER_MANAGER_ROLE) {
        _removeWithdrawSigner(_signer);
    }

    function setSignerThreshold(uint256 _threshold) external onlyRole(SIGNER_MANAGER_ROLE) {
        _setSignerThreshold(_threshold);
    }

    // ************************************
    // *   wallet module Management       *
    // ************************************

    function addWalletModule(address _moduleAddress) external onlyRole(SIGNER_MANAGER_ROLE) {
        _addWalletModule(_moduleAddress);
    }

    function removeWalletModule(address _moduleAddress) external onlyRole(SIGNER_MANAGER_ROLE) {
        _removeWalletModule(_moduleAddress);
    }
}
