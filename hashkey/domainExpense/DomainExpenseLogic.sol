// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// OpenZeppelin Standard Imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Upgradeable Contracts
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// Interface Imports
import {IFeesManager} from "../setting/interfaces/IFeesManager.sol";
import {ITokenManager} from "../setting/interfaces/ITokenManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {ITransferAgent} from "../transfer/interfaces/ITransferAgent.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title ERC721Receiver
 * @dev Implementation of the {IERC721Receiver} interface.
 * This contract demonstrates how to safely handle ERC721 token transfers.
 */
contract ERC721Receiver is IERC721Receiver {
    /**
     * @dev Implementation of the IERC721Receiver interface function.
     * This function is called when an ERC721 token is transferred to this contract.
     * @return bytes4 The function selector to confirm successful receipt of the token
     * Note: The parameters are not used in this implementation but are required by the interface
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        // Return the function selector to indicate successful token receipt
        return this.onERC721Received.selector;
    }
}

/**
 * @title Domain Expense Management Contract
 * @notice Upgradeable UUPS proxy pattern implementation for domain-related financial operations
 * @dev Manages payment orders, refunds, and withdrawals with robust access control
 *
 * Key Features:
 * - Whitelist-based token validation
 * - Safe proxy authorization
 * - Administrative fund withdrawal capabilities
 * - Batch operations for payment/refund processing
 * - ERC20-compliant transaction handling with fail-safes
 * - Comprehensive order lifecycle tracking
 */
contract DomainExpenseLogic is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ERC721Receiver {
    using SafeERC20 for IERC20;

    /// @notice Enum representing the complete lifecycle states of payment orders
    enum OrderStatus {
        None, // 0: Order slot available (default state)
        Normal, // 1: Active and valid payment order
        Refunded // 2: Successfully processed refund
    }

    /// @notice Bundled payment request structure for batch operations
    struct PaymentRequest {
        address token; // ERC20 token address
        uint256 amount; // Payment amount in token units
        uint256 orderId; // Unique order identifier
        uint256 action; // Payment action
    }

    struct RefundRequest {
        uint256 orderId; // Unique order identifier
        uint256 action; // Refund action
    }

    /// @notice Structure for NFT recycling requests
    /// @dev Used in batch operations for NFT recycling
    /// @param nftAddress The address of the NFT contract to recycle from
    /// @param tokenId The specific NFT token ID to recycle
    struct recycleRequest {
        address nftAddress;
        uint256 tokenId;
    }

    /// @notice Comprehensive order tracking structure
    /// @dev Persists for auditability even after refunds
    /// @param user   Address of order creator
    /// @param token  ERC20 token address used for payment
    /// @param amount Payment amount in token decimals
    /// @param status Current lifecycle state (see OrderStatus)
    struct Order {
        address user;
        address token;
        uint256 amount;
        OrderStatus status;
    }

    // ------------------ State Variables ------------------ //
    /// @notice Address of SettingManager contract for system parameters
    address public settingManagerAddress;

    /// @notice Address of TransferAgent for secure token movements
    address public transferAgentAddress;

    /// @notice Order registry mapping (orderId => Order struct)
    mapping(uint256 => Order) public orders;

    // ---------------------- Events ----------------------- //
    /// @notice Emitted upon successful payment processing
    /// @param orderId Unique order identifier
    /// @param user    Payer's Ethereum address
    /// @param token   ERC20 token contract address
    /// @param amount  Transferred token amount
    event Payment(uint256 indexed orderId, address indexed user, address indexed token, uint256 amount, uint256 action);

    /// @notice Emitted when refund is successfully executed
    /// @param orderId Refunded order identifier
    /// @param user    Refund recipient address
    /// @param token   ERC20 token contract address
    /// @param amount  Refunded token amount
    event Refund(uint256 indexed orderId, address indexed user, address token, uint256 amount, uint256 action);

    /// @notice Emitted when an NFT is recycled
    /// @param user       The address of the user who recycled the NFT
    /// @param nftAddress The address of the NFT contract
    /// @param tokenId    The identifier for the specific NFT being recycled
    event RecycleNFT(address user, address indexed nftAddress, uint256 tokenId);

    /// @notice Emitted when an NFT is received
    /// @param user       The address of the user who received the NFT
    /// @param nftAddress The address of the NFT contract
    /// @param tokenId    The identifier for the specific NFT being received
    event ReceiveNFT(address user, address indexed nftAddress, uint256 tokenId);

    /// @notice Emitted during administrative withdrawals
    /// @param token    ERC20 token contract address
    /// @param amount   Withdrawn token amount
    /// @param receiver Destination address for funds
    event Withdraw(address indexed token, uint256 amount, address receiver);

    // --------------------- Modifiers ---------------------- //
    /// @notice Validates caller against Safe proxy whitelist
    /// @dev Consults SettingManager for proxy authorization
    /// @param _targetAddress Address to verify
    modifier isMultiSignatureWallet(address _targetAddress) {
        if (!IMultiSignatureWalletManager(settingManagerAddress).isMultiSignatureWallet(_targetAddress))
            revert("Invalid caller");
        _;
    }

    // ---------------- Initialization & Upgrade ------------ //
    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Disables direct initialization on implementation contract
    /// @dev Forces use of proxy pattern via UUPS upgradeability
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the proxy contract
     * @dev Sets up:
     * - Administrative role hierarchy
     * - External system dependencies
     * - UUPS upgrade pattern
     * @param _admin                  Initial administrative account
     * @param _settingManagerAddress  System configuration contract
     * @param _transferAgentAddress   Secure transfer middleware
     */
    function initialize(
        address _admin,
        address _settingManagerAddress,
        address _transferAgentAddress
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        settingManagerAddress = _settingManagerAddress;
        transferAgentAddress = _transferAgentAddress;
    }

    // ----------------- Core Functionality ----------------- //
    /**
     * @notice Processes multiple payments atomically
     * @dev Inherits same validations as single payment()
     * @param requests Array of PaymentRequest structures
     */
    function batchPayment(PaymentRequest[] memory requests) external isMultiSignatureWallet(msg.sender) {
        for (uint256 i = 0; i < requests.length; i++) {
            _payment(requests[i].token, requests[i].amount, requests[i].orderId, requests[i].action);
        }
    }

    /**
     * @notice Processes multiple refunds atomically
     * @dev Inherits same validations as single refund()
     * @param requests Array of order identifiers
     */
    function batchRefund(RefundRequest[] memory requests) external {
        for (uint256 i = 0; i < requests.length; i++) {
            _refund(requests[i].orderId, requests[i].action);
        }
    }

    /**
     * @notice Administrative treasury withdrawal
     * @dev Restricted to DEFAULT_ADMIN_ROLE
     * @param token   ERC20 token address
     * @param amount  Withdrawal quantity
     */
    function withdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address receiver = IFeesManager(settingManagerAddress).getDomainExpenseReceiver();
        if (receiver == address(0)) revert("Invalid withdrawal receiver");

        if (!ITokenManager(settingManagerAddress).isTokenWhitelisted(token)) revert("Invalid token");
        if (amount == 0 || amount > IERC20(token).balanceOf(address(this))) revert("Invalid withdrawal amount");

        emit Withdraw(token, amount, receiver);

        // Secure transfer via agent
        IERC20(token).safeTransfer(receiver, amount);

        ITransferAgent(transferAgentAddress).triggerEventERC20(
            ITransferAgent.ERC20TransferType.DomainExpenseWithdraw,
            token,
            address(this),
            receiver,
            amount
        );
    }

    /**
     * @notice Processes multiple NFT recycling operations atomically
     * @dev Requires caller to be a whitelisted multi-signature wallet
     * @param requests Array of recycleRequest structures
     */
    function batchRecycleNFT(recycleRequest[] memory requests) external isMultiSignatureWallet(msg.sender) {
        for (uint256 i = 0; i < requests.length; i++) {
            _recycleNFT(requests[i].nftAddress, requests[i].tokenId);
        }
    }

    function _recycleNFT(address nftAddress, uint256 tokenId) internal {
        emit RecycleNFT(msg.sender, nftAddress, tokenId);
        _transferERC721From(
            ITransferAgent.ERC721TransferType.DomainRecycle,
            nftAddress,
            tokenId,
            msg.sender,
            address(this)
        );
    }

    /**
     * @notice Processes multiple NFT receiving operations atomically
     * @dev Requires caller to be a whitelisted multi-signature wallet
     * @param requests Array of recycleRequest structures
     */
    function batchReceiveNFT(recycleRequest[] memory requests) external isMultiSignatureWallet(msg.sender) {
        for (uint256 i = 0; i < requests.length; i++) {
            _receiveNFT(requests[i].nftAddress, requests[i].tokenId);
        }
    }

    function _receiveNFT(address nftAddress, uint256 tokenId) internal {
        emit ReceiveNFT(msg.sender, nftAddress, tokenId);
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        ITransferAgent(transferAgentAddress).triggerEventERC721(
            ITransferAgent.ERC721TransferType.DomainReceive,
            nftAddress,
            tokenId,
            address(this),
            msg.sender
        );
    }

    // ------------------ Internal Helpers ------------------- //
    /**
     * @notice Executes ERC20 transfer via Transfer Agent
     * @dev Provides standardized transfer failure handling
     * @param _transferType Transfer type (ERC20 or ERC721)
     * @param _erc20Token  ERC20 token contract address
     * @param _amount      Transfer quantity
     * @param _from        Source address
     * @param _to          Destination address
     */
    function _transferERC20From(
        ITransferAgent.ERC20TransferType _transferType,
        address _erc20Token,
        uint256 _amount,
        address _from,
        address _to
    ) internal virtual {
        try
            ITransferAgent(transferAgentAddress).transferERC20(_transferType, _erc20Token, _from, _to, _amount)
        {} catch {
            revert("Not authorized or balance not enough");
        }
    }

    /**
     * @notice Executes ERC721 transfer via Transfer Agent
     * @dev Provides standardized transfer failure handling
     * @param _transferType Transfer type (ERC20 or ERC721)
     * @param _nftAddress  ERC721 contract address
     * @param _nftTokenId  ERC721 token ID
     * @param _from        Source address
     * @param _to          Destination address
     */
    function _transferERC721From(
        ITransferAgent.ERC721TransferType _transferType,
        address _nftAddress,
        uint256 _nftTokenId,
        address _from,
        address _to
    ) internal virtual {
        try
            ITransferAgent(transferAgentAddress).transferERC721(_transferType, _nftAddress, _nftTokenId, _from, _to)
        {} catch {
            revert("Not authorized or balance not enough");
        }
    }

    /**
     * @notice Core payment processing logic
     * @dev Contains shared validation and state management
     * @param token   ERC20 token address
     * @param amount  Payment quantity
     * @param orderId Unique order reference
     * @param action  Payment action
     */
    function _payment(address token, uint256 amount, uint256 orderId, uint256 action) internal virtual {
        // Input validation
        if (!ITokenManager(settingManagerAddress).isTokenWhitelisted(token)) revert("Invalid token");
        if (orders[orderId].status != OrderStatus.None) revert("Order already processed");

        // State update
        orders[orderId] = Order({user: msg.sender, token: token, amount: amount, status: OrderStatus.Normal});

        emit Payment(orderId, msg.sender, token, amount, action);

        // Fund transfer
        _transferERC20From(
            ITransferAgent.ERC20TransferType.DomainExpensePayment,
            token,
            amount,
            msg.sender,
            address(this)
        );
    }

    /**
     * @notice Core refund processing logic
     * @dev Contains shared validation and state management
     * @param orderId Target order identifier
     * @param action  Payment action
     */
    function _refund(uint256 orderId, uint256 action) internal virtual {
        Order storage order = orders[orderId];

        // State validation
        if (order.status != OrderStatus.Normal || order.user != msg.sender) revert("Invalid order");

        // Balance check
        uint256 contractBalance = IERC20(order.token).balanceOf(address(this));
        if (contractBalance < order.amount) revert("Insufficient balance");

        // State update
        order.status = OrderStatus.Refunded;
        emit Refund(orderId, order.user, order.token, order.amount, action);

        // Safe ERC20 transfer
        IERC20(order.token).safeTransfer(order.user, order.amount);

        ITransferAgent(transferAgentAddress).triggerEventERC20(
            ITransferAgent.ERC20TransferType.DomainExpenseRefund,
            order.token,
            address(this),
            order.user,
            order.amount
        );
    }

    // ---------------- Upgrade Authorization --------------- //
    /**
     * @notice UUPS upgrade authorization hook
     * @dev Restricts upgrade rights to DEFAULT_ADMIN_ROLE
     * @param newImplementation Address of new logic contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Reserve upgrade storage slots (gap) for future versions
    uint256[47] private __gap;
}
