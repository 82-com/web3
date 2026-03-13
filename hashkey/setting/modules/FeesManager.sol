// SPDX-License-Identifier: MIT
/// @title Fees Manager Contract
/// @notice Abstract contract for managing various fee structures in the Domain system
/// @author Domain Team
pragma solidity ^0.8.22;

import {IFeesManager} from "../interfaces/IFeesManager.sol";

/// @title FeesManager
/// @notice Abstract contract that implements fee management functionality
/// @dev This contract handles market fees, swap fees, withdrawal fees and domain expense receivers
abstract contract FeesManager is IFeesManager {
    /// @notice Storage slot constant for fees storage
    bytes32 private constant FeesStorageLocal = keccak256("domain.setting.fees");

    /// @notice Struct containing all fee-related storage
    /// @dev This struct holds all fee configurations in a single storage slot
    struct FeesStorage {
        MarketFees marketFees;
        SwapFees swapFees;
        address withdrawalFeeReceiver;
        address domainExpenseReceiver;
        OrderBookFees orderBookFees;
    }

    /// @notice Gets the FeesStorage from a predefined storage slot
    /// @return fs Reference to the FeesStorage struct
    function _getFeesStorage() private pure returns (FeesStorage storage fs) {
        bytes32 slot = FeesStorageLocal;
        assembly {
            fs.slot := slot
        }
    }

    /// @notice Initializes the FeesManager with default values
    /// @dev Sets initial fee rates and receivers
    /// @param defaultAddress The default address to receive all fees initially
    function __FeesManager_init(address defaultAddress) internal {
        _setMarketFees(defaultAddress, 25000, 25000, 5000, 5000, 5000);
        _setSwapFees(defaultAddress, 5000, 5000);
        _setWithdrawalFeeReceiver(defaultAddress);
        _setDomainExpenseReceiver(defaultAddress);
    }

    /// @notice Emitted when market fees are updated
    /// @param transactionFeeReceiver Address receiving transaction fees
    /// @param transactionFeeRate Rate for transaction fees (per million)
    /// @param nftCreatorFirstRoyaltyRate First sale royalty rate for NFT creators
    /// @param nftCreatorRoyaltyRate Subsequent sale royalty rate for NFT creators
    /// @param buyerInviterRoyaltyRate Royalty rate for buyer's inviter
    /// @param sellerInviterRoyaltyRate Royalty rate for seller's inviter
    /// @param denominator Denominator used for fee calculations (1_000_000)
    event MarketFeesUpdated(
        address transactionFeeReceiver,
        uint32 transactionFeeRate,
        uint32 nftCreatorFirstRoyaltyRate,
        uint32 nftCreatorRoyaltyRate,
        uint32 buyerInviterRoyaltyRate,
        uint32 sellerInviterRoyaltyRate,
        uint32 denominator
    );

    /// @notice Emitted when swap fees are updated
    /// @param swapFeeReceiver Address receiving swap fees
    /// @param swapFee Swap fee rate (per million)
    /// @param swapLpFee Swap liquidity provider fee rate (per million)
    /// @param denominator Denominator used for fee calculations (1_000_000)
    event SwapFeesUpdated(address swapFeeReceiver, uint32 swapFee, uint32 swapLpFee, uint32 denominator);

    /// @notice Emitted when order book fees are updated
    /// @param orderBookFeeReceiver Address receiving order book fees
    /// @param makerFee Maker fee rate
    /// @param takerFee Taker fee rate
    /// @param denominator Denominator used for fee calculations (1_000_000)
    event OrderBookFeesUpdated(address orderBookFeeReceiver, uint32 makerFee, uint32 takerFee, uint32 denominator);

    /// @notice Emitted when withdrawal fee receiver is updated
    /// @param withdrawalFeeReceiver New address for withdrawal fee receiver
    event WithdrawalFeeReceiverUpdated(address withdrawalFeeReceiver);

    /// @notice Emitted when domain expense receiver is updated
    /// @param domainExpenseReceiver New address for domain expense receiver
    event DomainExpenseReceiverUpdated(address domainExpenseReceiver);

    /// @notice Sets market fee parameters
    /// @dev All rates are per million (denominator is 1_000_000)
    /// @param _transactionFeeReceiver Address to receive transaction fees
    /// @param _transactionFeeRate Transaction fee rate
    /// @param _nftCreatorFirstRoyaltyRate First sale royalty rate for NFT creators
    /// @param _nftCreatorRoyaltyRate Subsequent sale royalty rate for NFT creators
    /// @param _buyerInviterRoyaltyRate Royalty rate for buyer's inviter
    /// @param _sellerInviterRoyaltyRate Royalty rate for seller's inviter
    function _setMarketFees(
        address _transactionFeeReceiver,
        uint32 _transactionFeeRate,
        uint32 _nftCreatorFirstRoyaltyRate,
        uint32 _nftCreatorRoyaltyRate,
        uint32 _buyerInviterRoyaltyRate,
        uint32 _sellerInviterRoyaltyRate
    ) internal {
        require(_transactionFeeReceiver != address(0), "Invalid transaction fee receiver");
        uint32 maxFeeRate = _maxFeeRate();
        if (
            _transactionFeeRate > maxFeeRate ||
            _nftCreatorFirstRoyaltyRate > maxFeeRate ||
            _nftCreatorRoyaltyRate > maxFeeRate ||
            _buyerInviterRoyaltyRate > maxFeeRate ||
            _sellerInviterRoyaltyRate > maxFeeRate
        ) revert("Invalid transaction fee rate");

        FeesStorage storage fs = _getFeesStorage();
        fs.marketFees = MarketFees({
            transactionFeeReceiver: _transactionFeeReceiver,
            transactionFeeRate: _transactionFeeRate,
            nftCreatorFirstRoyaltyRate: _nftCreatorFirstRoyaltyRate,
            nftCreatorRoyaltyRate: _nftCreatorRoyaltyRate,
            buyerInviterRoyaltyRate: _buyerInviterRoyaltyRate,
            sellerInviterRoyaltyRate: _sellerInviterRoyaltyRate,
            denominator: _feeDenominator()
        });
        emit MarketFeesUpdated(
            fs.marketFees.transactionFeeReceiver,
            fs.marketFees.transactionFeeRate,
            fs.marketFees.nftCreatorFirstRoyaltyRate,
            fs.marketFees.nftCreatorRoyaltyRate,
            fs.marketFees.buyerInviterRoyaltyRate,
            fs.marketFees.sellerInviterRoyaltyRate,
            fs.marketFees.denominator
        );
    }

    /// @notice Sets swap fee parameters
    /// @dev All rates are per million (denominator is 1_000_000)
    /// @param _swapFeeReceiver Address to receive swap fees
    /// @param _swapFee Swap fee rate
    /// @param _swapLpFee Swap liquidity provider fee rate
    function _setSwapFees(address _swapFeeReceiver, uint32 _swapFee, uint32 _swapLpFee) internal {
        if (_swapFeeReceiver == address(0)) revert("Invalid swap fee receiver");
        uint32 maxFeeRate = _maxFeeRate();
        if (_swapFee > maxFeeRate || _swapLpFee > maxFeeRate) revert("Invalid swap fee rate");

        FeesStorage storage fs = _getFeesStorage();
        fs.swapFees = SwapFees({
            swapFeeReceiver: _swapFeeReceiver,
            swapFee: _swapFee,
            swapLpFee: _swapLpFee,
            denominator: _feeDenominator()
        });
        emit SwapFeesUpdated(
            fs.swapFees.swapFeeReceiver,
            fs.swapFees.swapFee,
            fs.swapFees.swapLpFee,
            fs.swapFees.denominator
        );
    }

    /// @notice Sets order book fee parameters
    /// @dev All rates are per million (denominator is 1_000_000)
    /// @param _orderBookFeeReceiver Address to receive order book fees
    /// @param _makerFee Maker fee rate
    /// @param _takerFee Taker fee rate
    function _setOrderBookFees(address _orderBookFeeReceiver, uint32 _makerFee, uint32 _takerFee) internal {
        if (_orderBookFeeReceiver == address(0)) revert("Invalid order book fee receiver");
        uint32 maxFeeRate = _maxFeeRate();
        if (_makerFee > maxFeeRate) revert("Invalid order book fee rate");
        if (_takerFee > maxFeeRate) revert("Invalid order book fee rate");

        FeesStorage storage fs = _getFeesStorage();
        fs.orderBookFees = OrderBookFees({
            orderBookFeeReceiver: _orderBookFeeReceiver,
            makerFee: _makerFee,
            takerFee: _takerFee,
            denominator: _feeDenominator()
        });
        emit OrderBookFeesUpdated(
            fs.orderBookFees.orderBookFeeReceiver,
            fs.orderBookFees.makerFee,
            fs.orderBookFees.takerFee,
            fs.orderBookFees.denominator
        );
    }

    /// @notice Sets the withdrawal fee receiver address
    /// @param _newReceiver New address to receive withdrawal fees
    function _setWithdrawalFeeReceiver(address _newReceiver) internal {
        if (_newReceiver == address(0)) revert("Invalid withdrawal fee receiver");

        FeesStorage storage fs = _getFeesStorage();
        fs.withdrawalFeeReceiver = _newReceiver;
        emit WithdrawalFeeReceiverUpdated(fs.withdrawalFeeReceiver);
    }

    /// @notice Sets the domain expense receiver address
    /// @param _newReceiver New address to receive domain expenses
    function _setDomainExpenseReceiver(address _newReceiver) internal {
        if (_newReceiver == address(0)) revert("Invalid domain expense receiver");

        FeesStorage storage fs = _getFeesStorage();
        fs.domainExpenseReceiver = _newReceiver;
        emit DomainExpenseReceiverUpdated(fs.domainExpenseReceiver);
    }

    /// @notice Gets the current market fees structure
    /// @return MarketFees struct containing all market fee parameters
    function getMarketFeesStruct() public view returns (MarketFees memory) {
        return _getFeesStorage().marketFees;
    }

    /// @notice Gets the current swap fees structure
    /// @return SwapFees struct containing all swap fee parameters
    function getSwapFeesStruct() public view returns (SwapFees memory) {
        return _getFeesStorage().swapFees;
    }

    /// @notice Gets the current order book fees structure
    /// @return OrderBookFees struct containing all order book fee parameters
    function getOrderBookFeesStruct() public view returns (OrderBookFees memory) {
        return _getFeesStorage().orderBookFees;
    }

    /// @notice Gets the current withdrawal fee receiver address
    /// @return Address of the withdrawal fee receiver
    function getWithdrawalFeeReceiver() public view returns (address) {
        return _getFeesStorage().withdrawalFeeReceiver;
    }

    /// @notice Gets the current domain expense receiver address
    /// @return Address of the domain expense receiver
    function getDomainExpenseReceiver() public view returns (address) {
        return _getFeesStorage().domainExpenseReceiver;
    }

    /// @notice Returns the fee denominator used for rate calculations
    /// @dev All rates are per million (1_000_000)
    /// @return uint32 The denominator value (1_000_000)
    function _feeDenominator() internal pure returns (uint32) {
        return 1_000_000; // 1e6 in uint32
    }

    /// @notice Returns the maximum allowed fee rate
    /// @dev Used to validate fee rate inputs
    /// @return uint32 The maximum allowed fee rate (150_000 or 15%)
    function _maxFeeRate() internal pure returns (uint32) {
        return 150_000;
    }
}
