// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {TokenManager} from "./modules/TokenManager.sol";
import {SafeProxyManager} from "./modules/SafeProxyManager.sol";
import {FeeManager} from "./modules/FeeManager.sol";
import {WithdrawSignerManager} from "./modules/WithdrawSignerManager.sol";
import {TransferAgentManager} from "./modules/TransferAgentManager.sol";
import {FractionManager} from "./modules/FractionManager.sol";
import {SafeModuleManager} from "./modules/SafeModuleManager.sol";

/**
 * @title SettingManagerV4
 * @notice Central configuration manager for domain exchange system with:
 * - Token whitelisting and management (ERC20/ERC721/ERC1155)
 * - Safe proxy wallet management
 * - Transaction and royalty fee configuration
 * - Withdrawal signer management
 * - Transfer agent management
 * - Fractional ownership management
 * @dev Uses UUPS upgradeable pattern with role-based access control
 * Inherits functionality from multiple manager modules
 */
contract SettingManagerV4 is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    FeeManager,
    SafeProxyManager,
    TokenManager,
    TransferAgentManager,
    WithdrawSignerManager,
    FractionManager,
    SafeModuleManager
{
    // ************************************
    // *           Storage               *
    // ************************************

    /// @dev Role constants
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");
    bytes32 public constant SAFE_MANAGER_ROLE = keccak256("SAFE_MANAGER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant SIGNER_MANAGER_ROLE = keccak256("SIGNER_MANAGER_ROLE");

    // ************************************
    // *       Constructor & Init        *
    // ************************************

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin) public virtual initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(TOKEN_MANAGER_ROLE, _admin);
        _grantRole(SAFE_MANAGER_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
        _grantRole(SIGNER_MANAGER_ROLE, _admin);

        _setMarketFeeConfig(_admin, 25000, 0, 0);
        _setWithdrawalFeeReceiver(_admin);
        _setSwapFeeConfig(_admin, 0, 0);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ************************************
    // *      Token Management            *
    // ************************************

    /**
     * @notice Adds a token to the whitelist
     * @param token Address of the token to whitelist
     * @param tokenType Type of the token (ERC20, ERC721, ERC1155)
     * @dev Only callable by TOKEN_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If token already whitelisted
     */
    function addToken(address token, TokenType tokenType) external onlyRole(TOKEN_MANAGER_ROLE) {
        _addToken(token, tokenType);
    }

    /**
     * @notice Removes a token from the whitelist
     * @param token Address of the token to remove
     * @dev Only callable by TOKEN_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If token not in whitelist
     */
    function removeToken(address token) external onlyRole(TOKEN_MANAGER_ROLE) {
        _removeToken(token);
    }

    // ************************************
    // *   transfer agent Management      *
    // ************************************

    /**
     * @notice Adds a new transfer agent exchange address
     * @param exchange Address of the exchange to be authorized as transfer agent
     * @dev Only callable by TOKEN_MANAGER_ROLE
     * @custom:reverts AlreadyAuthorized If exchange is already authorized
     */
    function addTransferAgentExchange(address exchange) external onlyRole(TOKEN_MANAGER_ROLE) {
        _addTransferAgentExchange(exchange);
    }

    /**
     * @notice Removes a transfer agent exchange address
     * @param exchange Address of the exchange to be removed
     * @dev Only callable by TOKEN_MANAGER_ROLE
     * @custom:reverts NotAuthorized If exchange is not currently authorized
     */
    function removeTransferAgentExchange(address exchange) external onlyRole(TOKEN_MANAGER_ROLE) {
        _removeTransferAgentExchange(exchange);
    }

    // ************************************
    // *    Fraction Config Management      *
    // ************************************

    function setFractionConfig(
        uint64 _minVoteDuration,
        uint64 _maxVoteDuration,
        uint64 _votePercentage,
        uint64 _minAuctionDuration,
        uint64 _maxAuctionDuration,
        uint64 _bidIncreasePercentage,
        uint64 _minPresaleDuration,
        uint64 _maxPresaleDuration
    ) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setFractionConfig(
            _minVoteDuration,
            _maxVoteDuration,
            _votePercentage,
            _minAuctionDuration,
            _maxAuctionDuration,
            _bidIncreasePercentage,
            _minPresaleDuration,
            _maxPresaleDuration
        );
    }

    // ************************************
    // *      Safe Proxy Management       *
    // ************************************

    /**
     * @notice Adds a safe wallet to the whitelist
     * @param safe Address of the safe wallet to whitelist
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts AlreadyWhitelisted If safe already whitelisted
     */
    function addSafeProxy(address safe) external onlyRole(SAFE_MANAGER_ROLE) {
        _addSafeProxy(safe);
    }

    /**
     * @notice Removes a safe wallet from the whitelist
     * @param safe Address of the safe wallet to remove
     * @dev Only callable by SAFE_MANAGER_ROLE
     * @custom:reverts NotWhitelisted If safe not in whitelist
     */
    function removeSafeProxy(address safe) external onlyRole(SAFE_MANAGER_ROLE) {
        _removeSafeProxy(safe);
    }

    /**
     * @notice Checks if a safe wallet is whitelisted
     * @param safe Address of the safe wallet to check
     * @return bool True if safe is whitelisted
     */
    function isSafeWhitelisted(address safe) external view override returns (bool) {
        return _isSafeWhitelisted(safe) || safe == _marketFees.transactionFeeReceiver;
    }

    // ************************************
    // *      Fee Management              *
    // ************************************

    function setMarketFeeConfig(
        address _transactionFeeReceiver,
        uint64 _transactionFeeRate,
        uint64 _nftCreatorRoyaltyRate,
        uint64 _nftOwnerRoyaltyRate
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setMarketFeeConfig(_transactionFeeReceiver, _transactionFeeRate, _nftCreatorRoyaltyRate, _nftOwnerRoyaltyRate);
    }

    function setWithdrawalFeeReceiver(address _withdrawalFeeReceiver) external onlyRole(FEE_MANAGER_ROLE) {
        _setWithdrawalFeeReceiver(_withdrawalFeeReceiver);
    }

    function setSwapFeeConfig(
        address _swapFeeReceiver,
        uint64 _swapFee,
        uint64 _swapLpFee
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setSwapFeeConfig(_swapFeeReceiver, _swapFee, _swapLpFee);
    }

    // ************************************
    // *   withdraw signer Management     *
    // ************************************

    /**
     * @notice Adds a new authorized withdrawal signer address
     * @param signer Address of the signer to be added
     * @dev Only callable by SIGNER_MANAGER_ROLE
     * @custom:reverts AlreadyAuthorized If signer is already authorized
     */
    function addWithdrawSigner(address signer) external onlyRole(SIGNER_MANAGER_ROLE) {
        _addWithdrawSigner(signer);
    }

    /**
     * @notice Removes an authorized withdrawal signer address
     * @param signer Address of the signer to be removed
     * @dev Only callable by SIGNER_MANAGER_ROLE
     * @custom:reverts NotAuthorized If signer is not currently authorized
     */
    function removeWithdrawSigner(address signer) external onlyRole(SIGNER_MANAGER_ROLE) {
        _removeWithdrawSigner(signer);
    }

    // ************************************
    // *   safe module Management         *
    // ************************************

    /**
     * @notice Adds a new safe module address
     * @param _moduleAddress Address of the module to be added
     * @dev Only callable by SIGNER_MANAGER_ROLE
     * @custom:reverts AlreadyAuthorized If module is already authorized
     */
    function addSafeModule(address _moduleAddress) external onlyRole(SIGNER_MANAGER_ROLE) {
        _addSafeModule(_moduleAddress);
    }

    /**
     * @notice Removes a safe module address
     * @param _moduleAddress Address of the module to be removed
     * @dev Only callable by SIGNER_MANAGER_ROLE
     * @custom:reverts NotAuthorized If module is not currently authorized
     */
    function removeSafeModule(address _moduleAddress) external onlyRole(SIGNER_MANAGER_ROLE) {
        _removeSafeModule(_moduleAddress);
    }

    uint256[50] private __gap;
}
