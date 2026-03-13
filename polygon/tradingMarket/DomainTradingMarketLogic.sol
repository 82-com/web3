/// @title Domain Trading Market Logic
/// @notice Core implementation of the domain trading market with UUPS upgradeability
/// @author Domain Protocol Team
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITradingOrderStruct} from "./interfaces/ITradingOrderStruct.sol";

import {OrderManager} from "./OrderManager.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice Main contract implementing domain trading market functionality
/// @dev Uses UUPS upgrade pattern and includes reentrancy protection
contract DomainTradingMarketLogic is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuard,
    OrderManager,
    ITradingOrderStruct
{
    mapping(uint256 => bool) public fulfilled;

    /// @notice Emitted when an order is fulfilled
    /// @param orderId Unique identifier of the order
    /// @param orderType Type of order (BUY/SELL)
    /// @param offerer Address that created the order
    /// @param trade Address that fulfilled the order
    /// @param nftAddress Address of the NFT contract
    /// @param nftTokenId ID of the NFT token
    /// @param currency Address of the ERC20 token used
    /// @param price Amount of ERC20 tokens exchanged
    event OrderFulfilled(
        uint256 indexed orderId,
        OrderType orderType,
        address offerer,
        address trade,
        address nftAddress,
        uint256 nftTokenId,
        address currency,
        uint256 price
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract
     * @dev Sets up initial ownership and dependencies
     * @param initialOwner Address that will be the initial owner
     * @param _settingManagerAddress Address of the settings manager contract
     * @param _transferAgentAddress Address of the transfer agent contract
     */
    function initialize(
        address initialOwner,
        address _settingManagerAddress,
        address _transferAgentAddress
    ) public virtual initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        _setSettingManagerAddress(_settingManagerAddress);
        _setTransferAgentAddress(_transferAgentAddress);
    }

    /**
     * @notice Authorizes contract upgrades (UUPS pattern)
     * @dev Only callable by the owner
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Fulfills a single trading order
    /// @dev Only callable by multi-signature wallet with reentrancy protection
    /// @param order Order details to fulfill
    function fulfillOrder(Order calldata order) external nonReentrant isMultiSignatureWallet(msg.sender) {
        _fulfillOrder(order);
    }

    /// @notice Fulfills multiple trading orders in batch
    /// @dev Only callable by multi-signature wallet with reentrancy protection
    /// @param orders Array of order details to fulfill
    function batchFulfillOrders(Order[] calldata orders) external nonReentrant isMultiSignatureWallet(msg.sender) {
        for (uint256 i = 0; i < orders.length; i++) {
            _fulfillOrder(orders[i]);
        }
    }

    /// @notice Internal function to process order fulfillment
    /// @dev Handles both BUY and SELL order types
    /// @param order Order details to process
    function _fulfillOrder(Order calldata order) internal {
        require(!fulfilled[order.orderId], "Order already fulfilled");

        fulfilled[order.orderId] = true;
        emit OrderFulfilled(
            order.orderId,
            order.orderType,
            order.offerer,
            msg.sender,
            order.erc721Address,
            order.erc721Id,
            order.erc20Address,
            order.erc20Amount
        );

        if (order.orderType == OrderType.BUY) {
            _transferERC721From(order.erc721Address, order.erc721Id, msg.sender, order.offerer);
            _transferERC20FromSupportingFee(
                order.erc20Address,
                order.erc20Amount,
                order.offerer,
                msg.sender,
                order.erc721Address,
                order.erc721Id,
                order.offerInviter,
                order.takerInviter,
                order.isFirst
            );
        } else {
            _transferERC721From(order.erc721Address, order.erc721Id, order.offerer, msg.sender);
            _transferERC20FromSupportingFee(
                order.erc20Address,
                order.erc20Amount,
                msg.sender,
                order.offerer,
                order.erc721Address,
                order.erc721Id,
                order.takerInviter,
                order.offerInviter,
                order.isFirst
            );
        }
    }

    uint256[49] private __gap;
}
