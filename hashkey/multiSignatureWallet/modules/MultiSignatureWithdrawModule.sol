/// @title MultiSignatureWithdrawModule
/// @notice A specialized withdrawal module for multi-signature wallets
/// @dev Implements ERC20 token withdrawals with fee collection and signature verification
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IVerifySignatures} from "../interfaces/IVerifySignatures.sol";
import {IFeesManager} from "../../setting/interfaces/IFeesManager.sol";
import {IWithdrawSignerManager} from "../../setting/interfaces/IWithdrawSignerManager.sol";

/// @notice Core withdrawal module for multi-signature wallets
/// @dev Handles ERC20 token withdrawals with fee collection and implements signature verification
contract MultiSignatureWithdrawModule is IVerifySignatures {
    using ECDSA for bytes32;

    /// @notice Contract version number
    uint256 public constant VERSIONS = 1;

    /// @notice Emitted when ERC20 tokens are withdrawn
    /// @param tokenAddress Address of the ERC20 token
    /// @param from Address sending the tokens (contract address)
    /// @param to Recipient address
    /// @param amount Amount of tokens withdrawn
    event ERC20Withdrawal(address indexed tokenAddress, address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when withdrawal fees are collected
    /// @param tokenAddress Address of the ERC20 token
    /// @param from Address sending the tokens (contract address)
    /// @param to Fee receiver address
    /// @param amount Amount of fees collected
    event FeeCollected(address indexed tokenAddress, address indexed from, address indexed to, uint256 amount);

    /// @notice Address of the SettingManager contract
    /// @dev Used to access fee settings and signer information
    address public immutable settingManagerAddress;

    /// @notice Initializes the contract with SettingManager address
    /// @param _settingManagerAddress Address of the SettingManager contract
    constructor(address _settingManagerAddress) {
        settingManagerAddress = _settingManagerAddress;
    }

    /// @notice Transfers ERC20 tokens to recipient with fee collection
    /// @dev Validates token address and sufficient balance before transfer
    /// @param tokenAddress Address of the ERC20 token to transfer
    /// @param to Recipient address
    /// @param amount Amount to transfer to recipient
    /// @param feeAmount Fee amount to collect
    function ERC20Transfer(address tokenAddress, address to, uint256 amount, uint256 feeAmount) external {
        require(tokenAddress != address(0), "invalid token address");

        IERC20 tokenERC20 = IERC20(tokenAddress);
        require(tokenERC20.balanceOf(address(this)) >= amount + feeAmount, "insufficient token balance");

        tokenERC20.transfer(to, amount);
        emit ERC20Withdrawal(tokenAddress, address(this), to, amount);
        
        if (feeAmount > 0) {
            address feeReceiver = IFeesManager(settingManagerAddress).getWithdrawalFeeReceiver();
            tokenERC20.transfer(feeReceiver, feeAmount);
            emit FeeCollected(tokenAddress, address(this), feeReceiver, feeAmount);
        }
    }

    /// @notice Verifies a set of signatures against the required threshold
    /// @dev Checks signatures against the current signer set and threshold
    /// @param dataHash Hash of the data that was signed
    /// @param signatures Array of signatures to verify
    /// @return true if sufficient valid signatures are provided, false otherwise
    function verifySignatures(bytes32 dataHash, bytes[] calldata signatures) public view returns (bool) {
        IWithdrawSignerManager settingManager = IWithdrawSignerManager(settingManagerAddress);
        uint256 threshold = settingManager.getSignerThreshold();
        address[] memory signers = settingManager.getWithdrawSignerSet();
        if (signers.length == 0 || threshold == 0) revert("no signers or threshold");

        uint256 validCount = 0;
        address[] memory seen = new address[](signers.length);

        // Check if number of signatures meets the threshold
        if (signatures.length < threshold) {
            return false;
        }

        for (uint256 i = 0; i < signatures.length; i++) {
            address recovered = dataHash.recover(signatures[i]);

            // Skip invalid signatures or non-signers
            if (!settingManager.isWithdrawSigner(recovered)) {
                continue;
            }

            // Check if this signer has already been counted
            bool alreadySeen = false;
            for (uint256 j = 0; j < validCount; j++) {
                if (seen[j] == recovered) {
                    alreadySeen = true;
                    break;
                }
            }

            if (!alreadySeen) {
                seen[validCount] = recovered;
                validCount++;

                // Early return if threshold is reached
                if (validCount >= threshold) {
                    return true;
                }
            }
        }
        return validCount >= threshold;
    }
}
