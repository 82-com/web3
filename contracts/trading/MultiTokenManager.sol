// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ISettingManager} from "../interfaces/ISettingManager.sol";
import {ITransferAgent} from "../interfaces/ITransferAgent.sol";
import {ERC721Receiver} from "./ERC721Receiver.sol";

/**
 * @title MultiTokenManager
 * @dev A contract for managing multiple token types (ERC20 and ERC721) with collateral actions,
 * fee calculations, and whitelist functionality. Inherits from ERC721Receiver and OwnableUpgradeable.
 */
contract MultiTokenManager is ERC721Receiver, OwnableUpgradeable {
    // Struct containing fee information for transactions
    struct FeeInfo {
        address txFeeReceiver; // Transaction fee receiver address
        address crFeeReceiver; // Creator fee receiver address
        uint256 txFee; // Transaction fee amount
        uint256 crFee; // Creator royalty fee amount
        uint256 ownFee; // Owner royalty fee amount
        uint256 remainingAmount; // Remaining amount after fees
    }

    // Mapping to track pledged token balances: promisee => (token address => amount)
    mapping(address => mapping(address => uint256)) public pledgeTokenMapping;

    // Address of the setting manager contract
    address public settingManagerAddress;

    // Address of the transfer agent contract
    address public transferAgentAddress;

    // Event
    event FeesDistributed(uint256 txFee, uint256 crFee, uint256 ownFee, uint256 remainingAmount);

    // Custom errors
    error ERROR_TransferFailed();
    error ERROR_NotWhitelisted();
    error ERROR_FEES_EXCEED_AMOUNT();
    error ERROR_NOT_SAFE_PROXY();

    /**
     * @dev Modifier to check if address is in safe proxy whitelist
     * @param _to Address to check
     */
    modifier isSafeProxy(address _to) {
        if (!ISettingManager(settingManagerAddress).isSafeWhitelisted(_to)) {
            revert ERROR_NOT_SAFE_PROXY();
        }
        _;
    }

    /**
     * @dev Checks if token addresses are whitelisted
     * @param _erc20Token Token address to check
     * @param _erc721Token NFT address to check
     * @return bool True if both addresses are whitelisted
     */
    function isAddressInWhiteList(address _erc20Token, address _erc721Token) internal view virtual returns (bool) {
        ISettingManager settingManager = ISettingManager(settingManagerAddress);
        return settingManager.isTokenWhitelisted(_erc20Token) && settingManager.isTokenWhitelisted(_erc721Token);
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
    ) internal virtual isSafeProxy(_to) {
        ITransferAgent transferAgent = ITransferAgent(transferAgentAddress);
        try transferAgent.transferERC721(_erc721Token, _nftTokenId, _from, _to) {} catch {
            revert ERROR_TransferFailed();
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
        address _erc20Token,
        uint256 _amount,
        address _from,
        address _to
    ) internal virtual isSafeProxy(_to) {
        if (_amount == 0) return;
        ITransferAgent transferAgent = ITransferAgent(transferAgentAddress);
        try transferAgent.transferERC20(_erc20Token, _from, _to, _amount) {} catch {
            revert ERROR_TransferFailed();
        }
    }

    /**
     * @dev Calculates all applicable fees for a transaction
     * @param _amount Transaction amount
     * @param _erc721Token Associated NFT contract address
     * @param _nftTokenId Associated NFT token ID
     * @return feeInfo Struct containing all fee information
     */
    function _calculateFees(
        uint256 _amount,
        address _erc721Token,
        uint256 _nftTokenId
    ) internal view virtual returns (FeeInfo memory) {
        (
            address txFeeReceiver,
            address crFeeReceiver,
            uint64 txFeeRate,
            uint64 crFeeRate,
            uint64 ownFeeRate,
            uint64 denominator
        ) = ISettingManager(settingManagerAddress).getMarketFeeConfig(_erc721Token, _nftTokenId);

        uint256 amount = _amount;
        uint256 txFee = (amount * txFeeRate) / denominator;
        uint256 crFee = (amount * crFeeRate) / denominator;
        uint256 ownFee = (amount * ownFeeRate) / denominator;
        uint256 totalFee = txFee + crFee + ownFee;

        if (totalFee > amount) {
            revert ERROR_FEES_EXCEED_AMOUNT();
        }

        uint256 remainingAmount = amount - totalFee;
        return FeeInfo(txFeeReceiver, crFeeReceiver, txFee, crFee, ownFee, remainingAmount);
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
        uint256 _nftTokenId
    ) internal virtual {
        if (_amount == 0) return;

        FeeInfo memory feeInfo = _calculateFees(_amount, _erc721Token, _nftTokenId);

        emit FeesDistributed(feeInfo.txFee, feeInfo.crFee, feeInfo.ownFee, feeInfo.remainingAmount);

        _transferERC20From(_erc20Token, feeInfo.txFee, _from, feeInfo.txFeeReceiver);
        _transferERC20From(_erc20Token, feeInfo.crFee, _from, feeInfo.crFeeReceiver);
        _transferERC20From(_erc20Token, feeInfo.ownFee, _from, _to);
        _transferERC20From(_erc20Token, feeInfo.remainingAmount, _from, _to);
    }

    uint256[7] private __gap;
}
