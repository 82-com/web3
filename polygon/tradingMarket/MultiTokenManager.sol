/// @title MultiTokenManager
/// @notice A contract for managing multiple token types (ERC20 and ERC721) with collateral actions, fee calculations, and whitelist functionality
/// @dev This contract handles token transfers with fee distribution and inviter relationships
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IFeesManager} from "../setting/interfaces/IFeesManager.sol";
import {ITokenManager} from "../setting/interfaces/ITokenManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {ITransferAgent} from "../transfer/interfaces/ITransferAgent.sol";
import {IDomainNFT} from "../domainNft/interfaces/IDomainNFT.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Receiver} from "./ERC721Receiver.sol";

/// @notice Manages multiple token types with fee calculations and transfer functionality
/// @dev Inherits from no base contracts, uses multiple manager interfaces
contract MultiTokenManager is ERC721Receiver, OwnableUpgradeable {
    /// @notice Struct containing fee information for transactions
    /// @dev Used to store all fee related information during token transfers
    struct FeeInfo {
        /// @notice Transaction fee receiver address
        address txFeeReceiver;
        /// @notice Creator fee receiver address
        address crFeeReceiver;
        /// @notice Buyer inviter fee receiver address
        address biFeeReceiver;
        /// @notice Seller inviter fee receiver address
        address siFeeReceiver;
        /// @notice Transaction fee amount
        uint256 txFee;
        /// @notice Creator royalty fee amount
        uint256 crFee;
        /// @notice Buyer inviter royalty fee amount
        uint256 biFee;
        /// @notice Seller inviter royalty fee amount
        uint256 siFee;
        /// @notice Remaining amount after fees
        uint256 remainingAmount;
    }

    /// @notice Struct used for fee calculation input
    /// @dev Contains all necessary parameters for fee calculation
    struct FeesCalculate {
        /// @notice Transfer amount
        uint256 amount;
        /// @notice ERC721 token address
        address erc721Token;
        /// @notice NFT token ID
        uint256 nftTokenId;
        /// @notice Buyer address
        address buyer;
        /// @notice Seller address
        address seller;
        /// @notice Buyer inviter address
        address buyerInviter;
        /// @notice Seller inviter address
        address sellerInviter;
        /// @notice Whether the NFT is the first trade
        bool isFirst;
    }

    /// @notice Mapping to track inviter relationships
    /// @dev user address => inviter address
    mapping(address => address) public inviterMapping_discard;

    /// @notice Mapping to track if NFT has been traded before
    /// @dev nft address => (nft token ID => not first)
    mapping(address => mapping(uint256 => bool)) public nftIsNotFristMapping;

    /// @notice Address of the setting manager contract
    address public settingManagerAddress;

    /// @notice Address of the transfer agent contract
    address public transferAgentAddress;

    /// @notice Emitted when an NFT is marked as not first trade
    /// @param nftAddress The address of the NFT contract
    /// @param nftTokenId The ID of the NFT token
    event NftIsNotFirst(address nftAddress, uint256 nftTokenId);

    /// @notice Modifier to check if target address is a safe receiver
    /// @dev Reverts if target address is not a safe receiver
    /// @param _targetAddr The address to check
    modifier isSafeReceiver(address _targetAddr) {
        if (!IMultiSignatureWalletManager(settingManagerAddress).isSafeReceiver(_targetAddr))
            revert("Not a safe receiver");
        _;
    }

    modifier isMultiSignatureWallet(address _targetAddr) {
        if (!IMultiSignatureWalletManager(settingManagerAddress).isMultiSignatureWallet(_targetAddr))
            revert("Not an octopus wallet");
        _;
    }

    /**
     * @dev Checks if token addresses are whitelisted
     * @param _erc20Token Token address to check
     * @param _erc721Token NFT address to check
     * @return bool True if both addresses are whitelisted
     */
    function isAddressInWhiteList(address _erc20Token, address _erc721Token) internal view virtual returns (bool) {
        ITokenManager settingManager = ITokenManager(settingManagerAddress);
        return settingManager.isTokenWhitelisted(_erc20Token) && settingManager.isTokenWhitelisted(_erc721Token);
    }

    function _setSettingManagerAddress(address _settingManagerAddress) internal {
        settingManagerAddress = _settingManagerAddress;
    }

    function _setTransferAgentAddress(address _transferAgentAddress) internal {
        transferAgentAddress = _transferAgentAddress;
    }

    /**
     * @dev Transfers ERC721 token using transfer agent
     * @param _erc721Token NFT contract address
     * @param _nftTokenId NFT token ID
     * @param _from Sender address
     * @param _to Recipient address
     */
    function _transferERC721From(
        address _erc721Token,
        uint256 _nftTokenId,
        address _from,
        address _to
    ) internal virtual isSafeReceiver(_to) {
        ITransferAgent transferAgent = ITransferAgent(transferAgentAddress);
        try
            transferAgent.transferERC721(
                ITransferAgent.ERC721TransferType.TradeFeeTransfer,
                _erc721Token,
                _nftTokenId,
                _from,
                _to
            )
        {} catch {
            revert("Not authorized or balance not enough");
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
    ) internal virtual isSafeReceiver(_to) {
        if (_amount == 0) return;
        ITransferAgent transferAgent = ITransferAgent(transferAgentAddress);
        try transferAgent.transferERC20(_transferType, _erc20Token, _from, _to, _amount) {} catch {
            revert("Not authorized or balance not enough");
        }
    }

    /**
     * @dev Calculates all applicable fees for a transaction
     * @param feesCalculate Struct
     * @return feeInfo Struct containing all fee information
     */
    function _calculateFees(FeesCalculate memory feesCalculate) internal virtual returns (FeeInfo memory) {
        IFeesManager.MarketFees memory marketFees = IFeesManager(settingManagerAddress).getMarketFeesStruct();

        address buyerInviter = feesCalculate.buyerInviter;
        address sellerInviter = feesCalculate.sellerInviter;

        uint256 txFee = (feesCalculate.amount * marketFees.transactionFeeRate) / marketFees.denominator;
        uint256 buyerInviterFee = (feesCalculate.amount * marketFees.buyerInviterRoyaltyRate) / marketFees.denominator;
        uint256 sellerInviterFee = (feesCalculate.amount * marketFees.sellerInviterRoyaltyRate) /
            marketFees.denominator;

        uint256 crFee = (feesCalculate.amount * marketFees.nftCreatorRoyaltyRate) / marketFees.denominator;

        if (!nftIsNotFristMapping[feesCalculate.erc721Token][feesCalculate.nftTokenId]) {
            nftIsNotFristMapping[feesCalculate.erc721Token][feesCalculate.nftTokenId] = true;
            emit NftIsNotFirst(feesCalculate.erc721Token, feesCalculate.nftTokenId);
            if (feesCalculate.isFirst) {
                crFee = (feesCalculate.amount * marketFees.nftCreatorFirstRoyaltyRate) / marketFees.denominator;
            }
        }

        uint256 totalFee = txFee + crFee + buyerInviterFee + sellerInviterFee;

        if (totalFee > feesCalculate.amount) revert("Total fee is greater than amount");

        uint256 remainingAmount = feesCalculate.amount - totalFee;

        return
            FeeInfo(
                marketFees.transactionFeeReceiver,
                IDomainNFT(feesCalculate.erc721Token).minters(feesCalculate.nftTokenId),
                buyerInviter == address(0) ? marketFees.transactionFeeReceiver : buyerInviter,
                sellerInviter == address(0) ? marketFees.transactionFeeReceiver : sellerInviter,
                txFee,
                crFee,
                buyerInviterFee,
                sellerInviterFee,
                remainingAmount
            );
    }

    /**
     * @dev Transfers ERC20 with fee support from external address
     * @param _erc20Token Token address
     * @param _amount Amount to transfer
     * @param _from Sender address
     * @param _to Recipient address
     * @param _erc721Token Associated NFT address
     * @param _nftTokenId Associated NFT token ID
     */
    function _transferERC20FromSupportingFee(
        address _erc20Token,
        uint256 _amount,
        address _from,
        address _to,
        address _erc721Token,
        uint256 _nftTokenId,
        address _fromInviter,
        address _toInviter,
        bool _isFirst
    ) internal virtual {
        if (_amount == 0) return;

        FeeInfo memory feeInfo = _calculateFees(
            FeesCalculate(_amount, _erc721Token, _nftTokenId, _from, _to, _fromInviter, _toInviter, _isFirst)
        );

        _transferERC20From(
            ITransferAgent.ERC20TransferType.FeeToProject,
            _erc20Token,
            feeInfo.txFee,
            _from,
            feeInfo.txFeeReceiver
        );
        _transferERC20From(
            ITransferAgent.ERC20TransferType.FeeToMinter,
            _erc20Token,
            feeInfo.crFee,
            _from,
            feeInfo.crFeeReceiver
        );
        _transferERC20From(
            ITransferAgent.ERC20TransferType.BuyerInviteFee,
            _erc20Token,
            feeInfo.biFee,
            _from,
            feeInfo.biFeeReceiver
        );
        _transferERC20From(
            ITransferAgent.ERC20TransferType.SellerInviteFee,
            _erc20Token,
            feeInfo.siFee,
            _from,
            feeInfo.siFeeReceiver
        );
        _transferERC20From(
            ITransferAgent.ERC20TransferType.TradeFeeTransfer,
            _erc20Token,
            feeInfo.remainingAmount,
            _from,
            _to
        );
    }

    uint256[5] private __gap;
}
