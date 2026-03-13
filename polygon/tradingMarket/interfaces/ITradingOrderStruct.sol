/// @title Trading Order Structure Interface
/// @notice Defines the data structures for trading orders
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITradingOrderStruct {
    /// @notice Order structure containing all trading details
    /// @param offerer Address of the order creator
    /// @param orderType Type of order (BUY/SELL)
    /// @param orderId Unique identifier to prevent order collision
    /// @param erc20Address Address of the ERC20 token involved
    /// @param erc20Amount Amount of ERC20 tokens involved
    /// @param erc721Address Address of the ERC721 token involved
    /// @param erc721Id ID of the ERC721 token involved
    /// @param offerInviter Address of the inviter who offered the order
    /// @param takerInviter Address of the inviter who accepted the order
    /// @param isFirst Boolean flag indicating if this is the first order in the market
    struct Order {
        address offerer;
        OrderType orderType;
        uint256 orderId;
        address erc20Address;
        uint256 erc20Amount;
        address erc721Address;
        uint256 erc721Id;
        address offerInviter;
        address takerInviter;
        bool isFirst;
    }

    /// @notice Enum representing order types
    enum OrderType {
        /// @notice Buy order (offering tokens for NFT)
        BUY,
        /// @notice Sell order (offering NFT for tokens)
        SELL
    }
}
