// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

import {IMultiSignatureValidator} from "./interfaces/IMultiSignatureValidator.sol";
import {IVerifySignatures} from "./interfaces/IVerifySignatures.sol";

/// @title Multi-Signature Validator Contract
/// @notice Implements multi-signature validation logic with configurable threshold
contract MultiSignatureValidator is IMultiSignatureValidator, IVerifySignatures, Initializable {
    using ECDSA for bytes32;

    /// @notice Storage structure for signer management
    /// @dev Uses mapping for O(1) signer lookup and array for iteration
    struct SignerStorage {
        address[] signers;           // List of authorized signers
        uint256 threshold;           // Minimum required signatures
        mapping(address => bool) isSigner;  // Mapping for signer existence check
    }

    /// @dev Storage slot for signer data to avoid storage collisions
    bytes32 private constant STORAGE_SLOT = keccak256("wallet.validator");

    /// @notice Returns the storage struct at predefined slot
    /// @return s Reference to the SignerStorage struct
    function _storage() private pure returns (SignerStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /// @notice Initializes the validator with initial signers and threshold
    /// @dev Can only be called once during contract initialization
    /// @param signers Array of initial signer addresses
    /// @param threshold Minimum number of required signatures
    function __MultiSignatureValidator_init(address[] memory signers, uint256 threshold) internal onlyInitializing {
        SignerStorage storage s = _storage();
        require(s.signers.length == 0, "Already initialized");
        
        // Ensure threshold doesn't exceed number of signers
        threshold = threshold > signers.length ? signers.length : threshold;

        for (uint256 i = 0; i < signers.length; i++) {
            _addSigner(signers[i]);
        }
        _setThreshold(threshold);
    }

    /// @notice Gets the current number of authorized signers
    /// @return Number of signers
    function getSignerCount() public view returns (uint256) {
        SignerStorage storage s = _storage();
        return s.signers.length;
    }

    /// @notice Gets the list of all authorized signers
    /// @return Array of signer addresses
    function getSigners() public view returns (address[] memory) {
        SignerStorage storage s = _storage();
        return s.signers;
    }

    /// @notice Checks if an address is an authorized signer
    /// @param addr Address to check
    /// @return True if address is a signer, false otherwise
    function isSigner(address addr) public view returns (bool) {
        SignerStorage storage s = _storage();
        return s.isSigner[addr];
    }

    /// @notice Gets the current signature threshold
    /// @return Current threshold value
    function getThreshold() public view returns (uint256) {
        SignerStorage storage s = _storage();
        return s.threshold;
    }

    // ============ Internal Functions ============

    /// @notice Adds a new signer to the validator
    /// @dev Internal function with access control checks
    /// @param signer Address of the new signer
    function _addSigner(address signer) internal {
        SignerStorage storage s = _storage();
        require(signer != address(0), "Invalid signer");
        require(!s.isSigner[signer], "Already signer");

        s.signers.push(signer);
        s.isSigner[signer] = true;
    }

    /// @notice Removes an existing signer from the validator
    /// @dev Automatically adjusts threshold if needed
    /// @param signer Address of the signer to remove
    function _removeSigner(address signer) internal {
        SignerStorage storage s = _storage();
        uint256 index = s.signers.length;
        
        // Find the signer in the array
        for (uint256 i = 0; i < s.signers.length; i++) {
            if (s.signers[i] == signer) {
                index = i;
                break;
            }
        }
        require(index < s.signers.length, "Not signer");

        // Move last element to current position
        uint256 lastIndex = s.signers.length - 1;
        if (index != lastIndex) {
            s.signers[index] = s.signers[lastIndex];
        }
        s.signers.pop();
        s.isSigner[signer] = false;

        // Auto-adjust threshold if it exceeds remaining signers
        if (s.threshold > s.signers.length) {
            s.threshold = s.signers.length;
            emit ThresholdChanged(s.threshold);
        }
    }

    /// @notice Sets the new signature threshold
    /// @dev Must be between 1 and current number of signers
    /// @param newThreshold New threshold value
    function _setThreshold(uint256 newThreshold) internal {
        require(newThreshold > 0 && newThreshold <= getSignerCount(), "Invalid threshold");
        SignerStorage storage s = _storage();
        s.threshold = newThreshold;
        emit ThresholdChanged(newThreshold);
    }

    // ============ Signature Verification ============

    /// @notice Verifies if the provided signatures meet the threshold requirement
    /// @dev Checks for valid signatures from distinct authorized signers
    /// @param dataHash Hash of the data that was signed
    /// @param signatures Array of signature bytes
    /// @return True if valid signatures meet threshold, false otherwise
    function verifySignatures(bytes32 dataHash, bytes[] calldata signatures) public view returns (bool) {
        SignerStorage storage s = _storage();
        uint256 validCount = 0;
        address[] memory seen = new address[](s.signers.length);

        // Early return if not enough signatures provided
        if (signatures.length < s.threshold) {
            return false;
        }

        for (uint256 i = 0; i < signatures.length; i++) {
            address recovered = dataHash.recover(signatures[i]);

            // Skip invalid signatures or non-signers
            if (!s.isSigner[recovered]) {
                continue;
            }

            // Check for duplicate signatures from same signer
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

                // Early return if threshold is met
                if (validCount >= s.threshold) {
                    return true;
                }
            }
        }
        return validCount >= s.threshold;
    }
}
