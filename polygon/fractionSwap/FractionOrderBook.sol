// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IFeesManager} from "../setting/interfaces/IFeesManager.sol";
import {ITokenManager} from "../setting/interfaces/ITokenManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {ITransferAgent} from "../transfer/interfaces/ITransferAgent.sol";

/// @notice Order structure
/// @param offerer Address of the order creator
/// @param orderId Unique identifier to prevent order collision
/// @param offerToken Address of the ERC20 token involved
/// @param offerAmount Amount of ERC20 tokens involved
/// @param wantToken Address of the base ERC20 token
/// @param wantAmount Amount of base ERC20 tokens
struct ERC20Order {
    address offerer;
    uint256 orderId;
    address offerToken;
    uint256 offerAmount;
    address wantToken;
    uint256 wantAmount;
    address feeToken;
}

/// @notice ERC20 Trading Market Logic contract
contract FractionOrderBook is ReentrancyGuard {
    /// @notice Address of the setting manager contract
    address public settingManagerAddress;

    /// @notice Address of the transfer agent contract
    address public transferAgentAddress;

    /// @notice Mapping to track if order ID has been used
    mapping(uint256 => bool) public fulfilled;

    /// @notice Emitted when an ERC20 order is fulfilled
    event ERC20OrderFulfilled(
        uint256 indexed orderId,
        address offerer,
        address trade,
        address offerToken,
        uint256 offerAmount,
        address wantToken,
        uint256 wantAmount,
        uint256 offerFee,
        uint256 wantFee
    );

    constructor(address _settingManager, address _transferAgent) {
        settingManagerAddress = _settingManager;
        transferAgentAddress = _transferAgent;
    }

    /// @notice Modifier to check if target address is a multi-signature wallet
    modifier isMultiSignatureWallet(address _targetAddr) {
        if (!IMultiSignatureWalletManager(settingManagerAddress).isMultiSignatureWallet(_targetAddr)) {
            revert("Not an octopus wallet");
        }
        _;
    }

    /// @notice Modifier to check if target address is a safe receiver
    /// @dev Reverts if target address is not a safe receiver
    /// @param _targetAddr The address to check
    modifier isSafeReceiver(address _targetAddr) {
        if (!IMultiSignatureWalletManager(settingManagerAddress).isSafeReceiver(_targetAddr))
            revert("Not a safe receiver");
        _;
    }

    function fulfillOrder(ERC20Order calldata order) external nonReentrant isMultiSignatureWallet(msg.sender) {
        _fulfillOrder(order);
    }

    function batchFulfillOrder(ERC20Order[] calldata order) external nonReentrant isMultiSignatureWallet(msg.sender) {
        for (uint256 i = 0; i < order.length; i++) {
            _fulfillOrder(order[i]);
        }
    }

    /**
     * @notice Fulfills an ERC20 trading order
     * @param order The ERC20 order to be fulfilled
     */
    function _fulfillOrder(ERC20Order calldata order) internal isMultiSignatureWallet(order.offerer) {
        require(!fulfilled[order.orderId], "Order has already been fulfilled");
        fulfilled[order.orderId] = true;

        // Read fee configuration
        IFeesManager.OrderBookFees memory fees = IFeesManager(settingManagerAddress).getOrderBookFeesStruct();

        uint256 makerFeeAmount = 0;
        uint256 takerFeeAmount = 0;

        bool chargeMaker;
        bool chargeTaker;

        // Determine which fees to charge (only 4 cases)
        if (order.feeToken == address(0)) {
            chargeMaker = false;
            chargeTaker = false;
        } else if (order.feeToken == address(1)) {
            chargeMaker = true;
            chargeTaker = true;
        } else if (order.feeToken == order.offerToken) {
            chargeMaker = true;
            chargeTaker = false;
        } else if (order.feeToken == order.wantToken) {
            chargeMaker = false;
            chargeTaker = true;
        } else {
            revert("Invalid feeToken");
        }

        // ====== Calculate Fees ======

        if (chargeMaker && fees.makerFee > 0) {
            makerFeeAmount = (order.offerAmount * fees.makerFee) / fees.denominator;
            require(makerFeeAmount <= order.offerAmount, "Maker fee overflow");
        }

        if (chargeTaker && fees.takerFee > 0) {
            takerFeeAmount = (order.wantAmount * fees.takerFee) / fees.denominator;
            require(takerFeeAmount <= order.wantAmount, "Taker fee overflow");
        }

        emit ERC20OrderFulfilled(
            order.orderId,
            order.offerer,
            msg.sender,
            order.offerToken,
            order.offerAmount,
            order.wantToken,
            order.wantAmount,
            makerFeeAmount,
            takerFeeAmount
        );

        // ====== Asset Transfers ======

        // Taker → Maker (wantToken, deducting taker fee)
        _transferERC20From(
            ITransferAgent.ERC20TransferType.OrderBookToMaker,
            order.wantToken,
            order.wantAmount - takerFeeAmount,
            msg.sender,
            order.offerer
        );

        // Maker → Taker (offerToken, deducting maker fee)
        _transferERC20From(
            ITransferAgent.ERC20TransferType.OrderBookToTaker,
            order.offerToken,
            order.offerAmount - makerFeeAmount,
            order.offerer,
            msg.sender
        );

        // Maker Fee
        if (makerFeeAmount > 0) {
            _transferERC20From(
                ITransferAgent.ERC20TransferType.OrderBookFeeToProject,
                order.offerToken,
                makerFeeAmount,
                order.offerer,
                fees.orderBookFeeReceiver
            );
        }

        // Taker Fee
        if (takerFeeAmount > 0) {
            _transferERC20From(
                ITransferAgent.ERC20TransferType.OrderBookFeeToProject,
                order.wantToken,
                takerFeeAmount,
                msg.sender,
                fees.orderBookFeeReceiver
            );
        }
    }

    /**
     * @dev Transfers ERC20 token using transfer agent
     * @param _erc20Token Token address
     * @param _amount Amount to transfer
     * @param _from Sender address
     * @param _to Recipient address
     */
    function _transferERC20From(
        ITransferAgent.ERC20TransferType _transferType,
        address _erc20Token,
        uint256 _amount,
        address _from,
        address _to
    ) internal virtual {
        if (_amount == 0) return;
        try
            ITransferAgent(transferAgentAddress).transferERC20(_transferType, _erc20Token, _from, _to, _amount)
        {} catch {
            revert("Not authorized or balance not enough");
        }
    }
}
