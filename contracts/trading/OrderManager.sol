// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDomainNFT} from "../interfaces/IDomainNFT.sol";
import {ISettingManager} from "../interfaces/ISettingManager.sol";
import {MultiTokenManager} from "./MultiTokenManager.sol";

/** error messages
 * MarketNotWhitelisted: Market contract is not in the whitelist of asset transfer contract callers
 * MakerNotWhitelisted: Order creator is not in the safeProxy whitelist of the setting contract
 * TakerNotWhitelisted: Order acceptor is not in the safeProxy whitelist of the setting contract
 * TokenNotWhitelisted: Token is not in the token whitelist of the setting contract
 * NotApproved: NFT contract is not approved for the asset transfer contract
 * AllowanceTooLow: Token contract allowance for the asset transfer contract is insufficient
 * InsufficientBalance: User token balance is insufficient
 * NotOwner: User is not the owner of the specified NFT
 * OrderAlreadyExists: Order already exists
 * OrderNotExists: Order does not exist
 * OrderExpired: Order has expired
 * InvalidEndTime: Order end time is invalid
 * InvalidPrice: Order price is invalid
 * NFTFrozen: NFT is frozen
 * SelfTradeForbidden: Trading with your own order is forbidden
 */

/**
 * @title OrderManager
 * @dev Manages buy/sell orders for NFTs with collateral handling
 */
contract OrderManager is MultiTokenManager {
    // Struct representing a maker order
    struct MakerOrder {
        address currency; // Currency address
        uint256 price; // Order price
        uint128 endTime; // Order expiration timestamp
    }

    // Enum for order types
    enum OrderType {
        Buy,
        Sell
    }
    // Enum for order action
    enum OrderAction {
        Create,
        Update,
        Cancel,
        Accept
    }

    // Mapping of order hash to maker order details
    mapping(bytes32 => MakerOrder) public makerOrderMapping;

    // Events
    event OrderCreated(
        bytes32 indexed orderHash,
        uint256 indexed orderId,
        OrderType orderType,
        address promisee,
        address nftAddress,
        uint256 nftTokenId,
        address currency,
        uint256 price,
        uint256 endTime
    );

    event OrderUpdated(
        bytes32 indexed orderHash,
        uint256 indexed orderId,
        OrderType orderType,
        address promisee,
        address nftAddress,
        uint256 nftTokenId,
        address currency,
        uint256 price,
        uint256 endTime
    );

    event OrderCancelled(
        bytes32 indexed orderHash,
        uint256 indexed orderId,
        OrderType orderType,
        address promisee,
        address nftAddress,
        uint256 nftTokenId,
        address currency
    );

    event OrderAccepted(
        bytes32 indexed orderHash,
        uint256 indexed orderId,
        OrderType orderType,
        address promisee,
        address trade,
        address nftAddress,
        uint256 nftTokenId,
        address currency,
        uint256 price
    );

    // Errors
    error ERROR_OrderAlreadyExists();
    error ERROR_OrderNotExist();
    error ERROR_OrderExpired();
    error ERROR_OrderInvalid();
    error ERROR_NFTIsFrozen();
    error ERROR_InvalidParams(string detail);

    /**
     * @dev Generates order hash key
     * @param _orderType Buy or Sell order type
     * @param _promisee Order maker address
     * @param _erc721Token NFT contract address
     * @param _nftTokenId NFT token ID
     * @param _orderId Unique order identifier
     * @return bytes32 Order hash
     */
    function getOrderKey(
        OrderType _orderType,
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId
    ) public pure virtual returns (bytes32) {
        return keccak256(abi.encode(_orderType, _promisee, _erc721Token, _nftTokenId, _orderId));
    }

    /**
     * @dev Validates order creation parameters
     * @return string Empty string if valid, error message if invalid
     */
    function _validateExternalConfig(
        OrderType _orderType,
        OrderAction _action,
        address _promisee,
        address _trade,
        address _erc721Token,
        address _erc20Token,
        uint256 _price
    ) internal view virtual returns (string memory) {
        ISettingManager settings = ISettingManager(settingManagerAddress);
        if (!settings.isTransferAgentExchange(address(this))) return "MarketNotWhitelisted";
        if (!settings.isSafeWhitelisted(_promisee)) return "MakerNotWhitelisted";
        if (!settings.isSafeWhitelisted(_trade)) return "TakerNotWhitelisted";
        if (_orderType == OrderType.Sell) {
            if (!IDomainNFT(_erc721Token).isApprovedForAll(_promisee, transferAgentAddress)) return "NotApproved";
            if (_action == OrderAction.Accept && IERC20(_erc20Token).allowance(_trade, transferAgentAddress) < _price)
                return "AllowanceTooLow";
        } else {
            if (IERC20(_erc20Token).allowance(_promisee, transferAgentAddress) < _price) return "AllowanceTooLow";
            if (
                _action == OrderAction.Accept &&
                !IDomainNFT(_erc721Token).isApprovedForAll(_trade, transferAgentAddress)
            ) return "NotApproved";
        }
        return "";
    }

    /**
     * @dev Validates order creation parameters
     * @return string Empty string if valid, error message if invalid
     */
    function _validateCreate(
        OrderType _orderType,
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        address _trade,
        MakerOrder memory _order
    ) internal view virtual returns (string memory) {
        if (_order.currency != address(0)) return "OrderAlreadyExists";
        if (!isAddressInWhiteList(_erc20Token, _erc721Token)) return "TokenNotWhitelisted";
        if (_endTime < block.timestamp) return "InvalidEndTime";
        if (_price == 0) return "InvalidPrice";

        if (_orderType == OrderType.Sell) {
            IDomainNFT nft = IDomainNFT(_erc721Token);
            if (nft.isFrozenTokenId(_nftTokenId)) return "NFTFrozen";
            try nft.ownerOf(_nftTokenId) returns (address nftOwner) {
                if (nftOwner != _trade) return "NotOwner";
            } catch {
                return "NotOwner";
            }
        } else {
            if (IERC20(_erc20Token).balanceOf(_trade) < _price) return "InsufficientBalance";
        }
        return "";
    }

    /**
     * @dev Validates order creation parameters
     * @return string Empty string if valid, error message if invalid
     */
    function _validateUpdate(
        OrderType _orderType,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _price,
        uint128 _endTime,
        address _trade,
        MakerOrder memory _order
    ) internal view virtual returns (string memory) {
        if (_order.currency == address(0)) return "OrderNotExists";
        if (!isAddressInWhiteList(_order.currency, _erc721Token)) return "TokenNotWhitelisted";
        if (_endTime < block.timestamp) return "InvalidEndTime";
        if (_price == 0) return "InvalidPrice";

        if (_orderType == OrderType.Sell) {
            IDomainNFT nft = IDomainNFT(_erc721Token);
            try nft.ownerOf(_nftTokenId) returns (address nftOwner) {
                if (nftOwner != _trade) return "NotOwner";
            } catch {
                return "NotOwner";
            }
        } else {
            if (IERC20(_order.currency).balanceOf(_trade) < _price) return "InsufficientBalance";
        }
        return "";
    }

    function _validateCancel(MakerOrder memory _order) internal view virtual returns (string memory) {
        if (_order.currency == address(0)) return "OrderNotExists";
        return "";
    }

    /**
     * @dev Validates order acceptance parameters
     * @return string Empty string if valid, error message if invalid
     */
    function _validateAccept(
        OrderType _orderType,
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        address _trade,
        MakerOrder memory _order,
        uint256 _acceptablePrice
    ) internal view virtual returns (string memory) {
        if (_order.currency == address(0)) return "OrderNotExists";
        if (!isAddressInWhiteList(_order.currency, _erc721Token)) return "TokenNotWhitelisted";
        if (_order.endTime < block.timestamp) return "OrderExpired";
        if (_promisee == msg.sender) return "SelfTradeForbidden";
        IDomainNFT nft = IDomainNFT(_erc721Token);
        if (nft.isFrozenTokenId(_nftTokenId)) return "NFTFrozen";
        if (_orderType == OrderType.Buy) {
            if (_order.price < _acceptablePrice) return "PriceTooLow";
            try nft.ownerOf(_nftTokenId) returns (address nftOwner) {
                if (nftOwner != _trade) return "NotOwner";
            } catch {
                return "NotOwner";
            }
            if (IERC20(_order.currency).balanceOf(_promisee) < _order.price) return "InsufficientBalance";
        } else {
            if (_order.price > _acceptablePrice) return "PriceTooHigh";
            try nft.ownerOf(_nftTokenId) returns (address nftOwner) {
                if (nftOwner != _promisee) return "NotOwner";
            } catch {
                return "NotOwner";
            }
            if (IERC20(_order.currency).balanceOf(_trade) < _order.price) return "InsufficientBalance";
        }
        return "";
    }

    /**
     * @dev Creates new sell order and deposits NFT
     */
    function _createSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId
    ) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Sell, msg.sender, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        string memory errorStr = _validateCreate(
            OrderType.Sell,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime,
            msg.sender,
            order
        );
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);
        makerOrderMapping[orderHash] = MakerOrder(_erc20Token, _price, _endTime);
        emit OrderCreated(
            orderHash,
            _orderId,
            OrderType.Sell,
            msg.sender,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime
        );
    }

    /**
     * @dev Creates new buy order with ERC20 collateral
     */
    function _createBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        address _erc20Token,
        uint256 _price,
        uint128 _endTime,
        uint256 _orderId
    ) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Buy, msg.sender, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        string memory errorStr = _validateCreate(
            OrderType.Buy,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime,
            msg.sender,
            order
        );
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);
        makerOrderMapping[orderHash] = MakerOrder(_erc20Token, _price, _endTime);
        emit OrderCreated(
            orderHash,
            _orderId,
            OrderType.Buy,
            msg.sender,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime
        );
    }

    /**
     * @dev Updates existing sell order
     */
    function _updateSellOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _price,
        uint128 _endTime,
        address _erc20Token,
        uint256 _orderId
    ) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Sell, msg.sender, _erc721Token, _nftTokenId, _orderId);
        MakerOrder storage order = makerOrderMapping[orderHash];
        string memory errorStr = _validateUpdate(
            OrderType.Sell,
            _erc721Token,
            _nftTokenId,
            _price,
            _endTime,
            msg.sender,
            order
        );
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);

        order.currency = _erc20Token;
        order.price = _price;
        order.endTime = _endTime;
        emit OrderUpdated(
            orderHash,
            _orderId,
            OrderType.Sell,
            msg.sender,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime
        );
    }

    /**
     * @dev Updates existing buy order
     */
    function _updateBuyOrder(
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _price,
        uint128 _endTime,
        address _erc20Token,
        uint256 _orderId
    ) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Buy, msg.sender, _erc721Token, _nftTokenId, _orderId);
        MakerOrder storage order = makerOrderMapping[orderHash];
        string memory errorStr = _validateUpdate(
            OrderType.Buy,
            _erc721Token,
            _nftTokenId,
            _price,
            _endTime,
            msg.sender,
            order
        );
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);

        order.currency = _erc20Token;
        order.price = _price;
        order.endTime = _endTime;
        emit OrderUpdated(
            orderHash,
            _orderId,
            OrderType.Buy,
            msg.sender,
            _erc721Token,
            _nftTokenId,
            _erc20Token,
            _price,
            _endTime
        );
    }

    /**
     * @dev Cancels sell order and returns NFT
     */
    function _cancelSellOrder(address _erc721Token, uint256 _nftTokenId, uint256 _orderId) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Sell, msg.sender, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        string memory errorStr = _validateCancel(order);
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);

        delete makerOrderMapping[orderHash];
        emit OrderCancelled(orderHash, _orderId, OrderType.Sell, msg.sender, _erc721Token, _nftTokenId, order.currency);
    }

    /**
     * @dev Cancels buy order and returns collateral
     */
    function _cancelBuyOrder(address _erc721Token, uint256 _nftTokenId, uint256 _orderId) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Buy, msg.sender, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        string memory errorStr = _validateCancel(order);
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);

        delete makerOrderMapping[orderHash];
        emit OrderCancelled(orderHash, _orderId, OrderType.Buy, msg.sender, _erc721Token, _nftTokenId, order.currency);
    }

    /**
     * @dev Executes sell order
     */
    function _acceptSellOrder(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        uint256 _acceptablePrice
    ) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Sell, _promisee, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        string memory errorStr = _validateAccept(
            OrderType.Sell,
            _promisee,
            _erc721Token,
            _nftTokenId,
            msg.sender,
            order,
            _acceptablePrice
        );
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);

        delete makerOrderMapping[orderHash];
        emit OrderAccepted(
            orderHash,
            _orderId,
            OrderType.Sell,
            _promisee,
            msg.sender,
            _erc721Token,
            _nftTokenId,
            order.currency,
            order.price
        );

        _transferERC20FromSupportingFee(order.currency, order.price, msg.sender, _promisee, _erc721Token, _nftTokenId);
        _transferERC721From(_erc721Token, _nftTokenId, _promisee, msg.sender);
    }

    /**
     * @dev Executes buy order
     */
    function _acceptBuyOrder(
        address _promisee,
        address _erc721Token,
        uint256 _nftTokenId,
        uint256 _orderId,
        uint256 _acceptablePrice
    ) internal virtual {
        bytes32 orderHash = getOrderKey(OrderType.Buy, _promisee, _erc721Token, _nftTokenId, _orderId);
        MakerOrder memory order = makerOrderMapping[orderHash];
        string memory errorStr = _validateAccept(
            OrderType.Buy,
            _promisee,
            _erc721Token,
            _nftTokenId,
            msg.sender,
            order,
            _acceptablePrice
        );
        if (bytes(errorStr).length > 0) revert ERROR_InvalidParams(errorStr);

        delete makerOrderMapping[orderHash];
        emit OrderAccepted(
            orderHash,
            _orderId,
            OrderType.Buy,
            _promisee,
            msg.sender,
            _erc721Token,
            _nftTokenId,
            order.currency,
            order.price
        );

        _transferERC721From(_erc721Token, _nftTokenId, msg.sender, _promisee);
        _transferERC20FromSupportingFee(order.currency, order.price, _promisee, msg.sender, _erc721Token, _nftTokenId);
    }

    uint256[9] private __gap;
}
