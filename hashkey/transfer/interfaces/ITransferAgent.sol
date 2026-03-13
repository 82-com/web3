// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ITransferAgent
 * @notice Interface for Transfer Agent contract that handles token transfers between whitelisted exchanges
 * @dev Defines the transfer types and events for ERC20 and ERC721 token transfers
 */
interface ITransferAgent {
    struct TransferERC20Params {
        ERC20TransferType transferType;
        address currency;
        address from;
        address to;
        uint256 amount;
    }
    struct TransferERC721Params {
        ERC721TransferType transferType;
        address nftAddress;
        uint256 nftTokenId;
        address from;
        address to;
    }

    /**
     * @dev Enum representing different types of ERC20 token transfers
     */
    enum ERC20TransferType {
        /// @dev Fee transferred to project
        FeeToProject,
        /// @dev Fee transferred to NFT minter
        FeeToMinter,
        /// @dev Buyer invite reward
        BuyerInviteFee,
        /// @dev Seller invite reward
        SellerInviteFee,
        /// @dev Actual trade amount transfer
        TradeFeeTransfer,
        /// @dev Payment for domain expenses
        DomainExpensePayment,
        /// @dev Refund for domain expenses
        DomainExpenseRefund,
        /// @dev Withdrawal from domain expenses
        DomainExpenseWithdraw,
        /// @dev Adding liquidity to swap pool
        AddLiquidity,
        /// @dev Removing liquidity from swap pool
        RemoveLiquidity,
        /// @dev Token swap in swap pool
        SwapToken,
        /// @dev Bidding in fraction contract
        FractionBid,
        /// @dev Order book transaction transfer to maker (order placer)
        OrderBookToMaker,
        /// @dev Order book transaction transfer to taker (order executor)
        OrderBookToTaker,
        /// @dev Order book transaction fee transfer to project
        OrderBookFeeToProject
    }

    /**
     * @dev Enum representing different types of ERC721 token transfers
     */
    enum ERC721TransferType {
        /// @dev NFT transfer for trade completion
        TradeFeeTransfer,
        /// @dev Domain recycling transfer
        DomainRecycle,
        /// @dev Domain receiving transfer
        DomainReceive,
        /// @dev NFT fragmentation transfer
        DomainDebris
    }

    /**
     * @notice Emitted when ERC20 tokens are transferred
     * @param _transferType Type of ERC20 transfer
     * @param currency Address of the ERC20 token
     * @param from Address sending the tokens
     * @param to Address receiving the tokens
     * @param amount Amount of tokens transferred
     */
    event ERC20Transferred(
        ERC20TransferType _transferType,
        address indexed currency,
        address from,
        address to,
        uint256 amount
    );

    /**
     * @notice Emitted when ERC721 tokens are transferred
     * @param _transferType Type of ERC721 transfer
     * @param nft Address of the ERC721 token
     * @param from Address sending the NFT
     * @param to Address receiving the NFT
     * @param tokenId ID of the NFT transferred
     */
    event ERC721Transferred(
        ERC721TransferType _transferType,
        address indexed nft,
        address from,
        address to,
        uint256 tokenId
    );

    /**
     * @notice Transfers ERC20 tokens between addresses
     * @dev Only callable by whitelisted exchanges
     * @param _transferType Type of ERC20 transfer
     * @param _currency Address of the ERC20 token
     * @param _from Address sending the tokens
     * @param _to Address receiving the tokens
     * @param _amount Amount of tokens to transfer
     */
    function transferERC20(
        ERC20TransferType _transferType,
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) external;

    function batchTransferERC20(TransferERC20Params[] calldata) external;

    /**
     * @notice Transfers ERC721 tokens between addresses
     * @dev Only callable by whitelisted exchanges
     * @param _transferType Type of ERC721 transfer
     * @param _nftAddress Address of the ERC721 token
     * @param _nftTokenId ID of the NFT to transfer
     * @param _from Address sending the NFT
     * @param _to Address receiving the NFT
     */
    function transferERC721(
        ERC721TransferType _transferType,
        address _nftAddress,
        uint256 _nftTokenId,
        address _from,
        address _to
    ) external;

    function batchTransferERC721(TransferERC721Params[] calldata) external;

    /**
     * @notice Triggers ERC20 transfer event without actual transfer
     * @dev Only callable by whitelisted exchanges
     * @param _transferType Type of ERC20 transfer
     * @param _currency Address of the ERC20 token
     * @param _from Address that would send the tokens
     * @param _to Address that would receive the tokens
     * @param _amount Amount of tokens that would be transferred
     */
    function triggerEventERC20(
        ERC20TransferType _transferType,
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) external;

    /**
     * @notice Triggers ERC721 transfer event without actual transfer
     * @dev Only callable by whitelisted exchanges
     * @param _transferType Type of ERC721 transfer
     * @param _nftAddress Address of the ERC721 token
     * @param _nftTokenId ID of the NFT that would be transferred
     * @param _from Address that would send the NFT
     * @param _to Address that would receive the NFT
     */
    function triggerEventERC721(
        ERC721TransferType _transferType,
        address _nftAddress,
        uint256 _nftTokenId,
        address _from,
        address _to
    ) external;
}
