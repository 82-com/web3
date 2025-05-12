// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrderManager} from "./OrderManager.sol";

/**
 * @title NFTOfferMarketV4
 * @dev Upgradeable NFT marketplace contract supporting buy/sell orders with UUPS proxy pattern
 */
contract NFTOfferMarketV4 is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard, OrderManager {
    /**
     * @dev Struct for batch order processing
     */
    struct BatchOrder {
        address promisee; // Order maker address
        address erc721Token; // NFT contract address
        uint256 nftTokenId; // NFT token ID
        uint256 orderId; // Order UUID
        uint256 acceptablePrice; // Acceptable price
    }

    struct BatchCreateOrder {
        address _erc721Token;
        uint256 _nftTokenId;
        address _erc20Token;
        uint256 _price;
        uint128 _endTime;
        uint256 _orderId;
    }

    // Custom errors
    error ERROR_InvalidInputLengths(); // Input arrays have mismatched lengths
    error ERROR_AdminCannotCancelOrder(); // Admin cannot cancel non-expired orders

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the upgradeable contract
     * @param initialOwner Initial contract owner
     * @param _settingManagerAddress Settings manager contract address
     * @param _transferAgentAddress Transfer agent contract address
     */
    function initialize(
        address initialOwner,
        address _settingManagerAddress,
        address _transferAgentAddress
    ) public virtual initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        settingManagerAddress = _settingManagerAddress;
        transferAgentAddress = _transferAgentAddress;
    }

    /**
     * @dev Authorizes contract upgrades (UUPS pattern)
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Order Management Functions

    /**
     * @dev Creates a new sell order for NFT
     * @param _erc721Token NFT contract address
     * @param _nftTokenId NFT token ID
     * @param _erc20Token Payment token address
     * @param _price Order price
     * @param _endTime Order expiration timestamp
     */
    function createSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId
    ) public virtual {
        _createSellOrder(_erc721Token, _nftTokenId, _erc20Token, _price, _endTime, _orderId);
    }

    /**
     * @dev Creates a new buy order for NFT (with reentrancy protection)
     * @param _erc721Token NFT contract address
     * @param _nftTokenId NFT token ID
     * @param _erc20Token Payment token address
     * @param _price Order price
     * @param _endTime Order expiration timestamp
     */
    function createBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId
    ) public virtual {
        _createBuyOrder(_erc721Token, _nftTokenId, _erc20Token, _price, _endTime, _orderId);
    }

    /**
     * @dev Creates multiple sell orders in batch (with reentrancy protection)
     * @param _batchOrder Array of BatchCreateOrder structs
     */
    function batchCreateSellOrder(BatchCreateOrder[] calldata _batchOrder) external virtual nonReentrant {
        for (uint256 i = 0; i < _batchOrder.length; i++) {
            _createSellOrder(
                _batchOrder[i]._erc721Token,
                _batchOrder[i]._nftTokenId,
                _batchOrder[i]._erc20Token,
                _batchOrder[i]._price,
                _batchOrder[i]._endTime,
                _batchOrder[i]._orderId
            );
        }
    }

    /**
     * @dev Creates multiple buy orders in batch (with reentrancy protection)
     * @param _batchOrder Array of BatchCreateOrder structs
     */
    function batchCreateBuyOrder(BatchCreateOrder[] calldata _batchOrder) external virtual nonReentrant {
        for (uint256 i = 0; i < _batchOrder.length; i++) {
            _createBuyOrder(
                _batchOrder[i]._erc721Token,
                _batchOrder[i]._nftTokenId,
                _batchOrder[i]._erc20Token,
                _batchOrder[i]._price,
                _batchOrder[i]._endTime,
                _batchOrder[i]._orderId
            );
        }
    }

    /**
     * @dev Updates existing sell order parameters
     */
    function updateSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId
    ) public virtual {
        _updateSellOrder(_erc721Token, _nftTokenId, _price, _endTime, _erc20Token, _orderId);
    }

    /**
     * @dev Updates existing buy order parameters
     */
    function updateBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId
    ) public virtual {
        _updateBuyOrder(_erc721Token, _nftTokenId, _price, _endTime, _erc20Token, _orderId);
    }

    /**
     * @dev Cancels sell order and returns collateral
     */
    function cancelSellOrder(address _erc721Token, uint256 _nftTokenId, uint256 _orderId) public virtual {
        _cancelSellOrder(_erc721Token, _nftTokenId, _orderId);
    }

    /**
     * @dev Cancels buy order and returns collateral (with reentrancy protection)
     */
    function cancelBuyOrder(address _erc721Token, uint256 _nftTokenId, uint256 _orderId) public virtual {
        _cancelBuyOrder(_erc721Token, _nftTokenId, _orderId);
    }

    /**
     * @dev Executes sell order (with reentrancy protection)
     * @param _promisee Order maker address
     */
    function acceptSellOrder(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        uint256 _acceptablePrice
    ) public virtual nonReentrant {
        _acceptSellOrder(_promisee, _erc721Token, _nftTokenId, _orderId, _acceptablePrice);
    }

    /**
     * @dev Executes buy order (with reentrancy protection)
     * @param _promisee Order maker address
     */
    function acceptBuyOrder(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        uint256 _acceptablePrice
    ) public virtual nonReentrant {
        _acceptBuyOrder(_promisee, _erc721Token, _nftTokenId, _orderId, _acceptablePrice);
    }

    // Batch Operations

    /**
     * @dev Executes multiple sell orders in batch (with reentrancy protection)
     * @param _batchOrder Array of BatchOrder structs
     */
    function batchAcceptSellOrder(BatchOrder[] calldata _batchOrder) external virtual nonReentrant {
        for (uint256 i = 0; i < _batchOrder.length; i++) {
            _acceptSellOrder(
                _batchOrder[i].promisee,
                _batchOrder[i].erc721Token,
                _batchOrder[i].nftTokenId,
                _batchOrder[i].orderId,
                _batchOrder[i].acceptablePrice
            );
        }
    }

    /**
     * @dev Executes multiple buy orders in batch (with reentrancy protection)
     * @param _batchOrder Array of BatchOrder structs
     */
    function batchAcceptBuyOrder(BatchOrder[] calldata _batchOrder) external virtual nonReentrant {
        for (uint256 i = 0; i < _batchOrder.length; i++) {
            _acceptBuyOrder(
                _batchOrder[i].promisee,
                _batchOrder[i].erc721Token,
                _batchOrder[i].nftTokenId,
                _batchOrder[i].orderId,
                _batchOrder[i].acceptablePrice
            );
        }
    }

    // Admin Functions

    /**
     * @dev Admin function to cancel sell order (only expired orders)
     */
    function cancelSellOrderOnlyOwner(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId
    ) external virtual onlyOwner {
        bytes32 orderHash = getOrderKey(OrderType.Sell, _promisee, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        if (order.price == 0 && order.endTime == 0) revert ERROR_OrderNotExist();
        if (order.endTime > block.timestamp) revert ERROR_AdminCannotCancelOrder();

        delete makerOrderMapping[orderHash];
        emit OrderCancelled(orderHash, _orderId, OrderType.Sell, _promisee, _erc721Token, _nftTokenId, order.currency);
    }

    /**
     * @dev Admin function to cancel buy order (only expired orders, with reentrancy protection)
     */
    function cancelBuyOrderOnlyOwner(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId
    ) external virtual onlyOwner {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _promisee, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        if (order.price == 0 && order.endTime == 0) revert ERROR_OrderNotExist();
        if (order.endTime > block.timestamp) revert ERROR_AdminCannotCancelOrder();

        delete makerOrderMapping[orderHash];
        emit OrderCancelled(orderHash, _orderId, OrderType.Buy, _promisee, _erc721Token, _nftTokenId, order.currency);
    }

    // Validation Functions

    /**
     * @dev Validates sell order creation parameters
     * @return str Empty if valid, error message if invalid
     */
    function validateCreateSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Sell, _safeProxy, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        str = _validateCreate(
            OrderType.Sell,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime,
            _safeProxy,
            order
        );
        if (bytes(str).length > 0) return str;
        return
            _validateExternalConfig(
                OrderType.Sell,
                OrderAction.Create,
                _safeProxy,
                _safeProxy,
                _erc721Token,
                _erc20Token,
                _price
            );
    }

    /**
     * @dev Validates buy order creation parameters
     * @return str Empty if valid, error message if invalid
     */
    function validateCreateBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _safeProxy, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        str = _validateCreate(
            OrderType.Buy,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime,
            _safeProxy,
            order
        );
        if (bytes(str).length > 0) return str;
        return
            _validateExternalConfig(
                OrderType.Buy,
                OrderAction.Create,
                _safeProxy,
                _safeProxy,
                _erc721Token,
                _erc20Token,
                _price
            );
    }

    function validateUpdateSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _safeProxy, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        str = _validateUpdate(OrderType.Sell, _erc721Token, _nftTokenId, _price, _endTime, _safeProxy, order);
        if (bytes(str).length > 0) return str;
        return
            _validateExternalConfig(
                OrderType.Sell,
                OrderAction.Update,
                _safeProxy,
                _safeProxy,
                _erc721Token,
                _erc20Token,
                _price
            );
    }

    function validateUpdateBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _safeProxy, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        str = _validateUpdate(OrderType.Buy, _erc721Token, _nftTokenId, _price, _endTime, _safeProxy, order);
        if (bytes(str).length > 0) return str;
        return
            _validateExternalConfig(
                OrderType.Buy,
                OrderAction.Update,
                _safeProxy,
                _safeProxy,
                _erc721Token,
                _erc20Token,
                _price
            );
    }

    function validateCancelSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Sell, _safeProxy, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        return _validateCancel(order);
    }

    function validateCancelBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _safeProxy, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        return _validateCancel(order);
    }

    /**
     * @dev Validates sell order acceptance parameters
     * @return str Empty if valid, error message if invalid
     */
    function validateAcceptSellOrder(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        uint256 _acceptablePrice,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Sell, _promisee, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        str = _validateAccept(
            OrderType.Sell,
            _promisee,
            _erc721Token,
            _nftTokenId,
            _safeProxy,
            order,
            _acceptablePrice
        );
        if (bytes(str).length > 0) return str;
        str = _validateExternalConfig(
            OrderType.Sell,
            OrderAction.Accept,
            _promisee,
            _safeProxy,
            _erc721Token,
            order.currency,
            order.price
        );
    }

    /**
     * @dev Validates buy order acceptance parameters
     * @return str Empty if valid, error message if invalid
     */
    function validateAcceptBuyOrder(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        uint256 _acceptablePrice,
        address _safeProxy
    ) external view virtual returns (string memory str) {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _promisee, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        str = _validateAccept(OrderType.Buy, _promisee, _erc721Token, _nftTokenId, _safeProxy, order, _acceptablePrice);
        if (bytes(str).length > 0) return str;
        str = _validateExternalConfig(
            OrderType.Buy,
            OrderAction.Accept,
            _promisee,
            _safeProxy,
            _erc721Token,
            order.currency,
            order.price
        );
    }

    uint256[50] private __gap;
}
