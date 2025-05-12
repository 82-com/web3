// SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import {SafeV2} from "../safe/Safe.sol";
import {SafeMath} from "@safe-global/safe-contracts/contracts/external/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISettingManager} from "../interfaces/ISettingManager.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SignatureDecoder} from "@safe-global/safe-contracts/contracts/common/SignatureDecoder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenWithdrawModuleV2
 * @dev Contract implementing a shared module that transfers tokens from any Safe contract to users having valid signatures.
 */
contract TokenWithdrawModuleV2 is SignatureDecoder, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public immutable TOKEN_TRANSFER_TYPE_HASH =
    keccak256(
        "tokenTransfer(address tokenAddress,address safeAddress,uint256 amount,address _beneficiary,uint256 nonce,uint256 deadline,uint256 _feeAmount)"
    );

    bytes32 public immutable NFT_TRANSFER_TYPE_HASH =
    keccak256(
        "nftTransfer(address tokenAddress,address safeAddress,uint256 tokenId,address recipient,uint256 nonce,uint256 deadline)"
    );
    
    mapping(address => uint256) public nonces;  // nonce per safe address

    /**
     * @dev Generates the EIP-712 domain separator for the contract.
     *
     * @return The EIP-712 domain separator.
     */
    function getDomainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("TokenWithdrawModuleV2")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Transfers a specified amount of tokens to a beneficiary.
     *
     * @param _tokenAddress address of the ERC20 token contract
     * @param _safeAddress address of the Safe contract
     * @param _amount amount of tokens to be transferred
     * @param _beneficiary address of the beneficiary
     * @param _deadline deadline for the validity of the signature
     * @param _feeAmount amount of tokens to be paid as fee
     * @param _signatures signatures of the Safe owner(s)
     */
    function tokenTransfer(
        address _tokenAddress,
        address _safeAddress,
        uint256 _amount,
        address _beneficiary,
        uint256 _deadline,
        uint256 _feeAmount,
        bytes memory _signatures
    ) public nonReentrant {
        require(_deadline >= block.timestamp, "expired deadline");
        require(_tokenAddress != address(0), "invalid token address");
        require(_safeAddress != address(0), "invalid safe address");

        // Check if the Safe has enough token balance
        require(IERC20(_tokenAddress).balanceOf(_safeAddress) >= _amount + _feeAmount, "insufficient token balance");

        SafeV2 safe = SafeV2(payable(_safeAddress));
        ISettingManager settingManager = safe.settingManager();
        require(address(settingManager) != address(0), "not setting manager found");

        bytes32 signatureData = keccak256(
            abi.encode(
                TOKEN_TRANSFER_TYPE_HASH,
                _tokenAddress,
                _safeAddress,
                _amount,
                _beneficiary,
                nonces[_safeAddress]++,
                _deadline,
                _feeAmount
            )
        );

        checkSignatures(
            signatureData, 
            _signatures, 
            safe,
            settingManager
        );
        
        // Step 1: Transfer to beneficiary
        _executeTokenTransfer(
            _tokenAddress, 
            _safeAddress, 
            _beneficiary, 
            _amount
        );
        
        // Step 2: Transfer fee to fee receiver (if needed)
        if (_feeAmount > 0) {
            _executeTokenTransfer(
                _tokenAddress,
                _safeAddress,
                settingManager.getWithdrawalFeeReceiver(),
                _feeAmount
            );
        }
    }

    /**
     * @dev Unified token transfer execution function
     * 
     * @param _tokenAddress Token contract address
     * @param _safeAddress Safe contract address
     * @param _recipient Recipient address
     * @param _amount Token amount
     */
    function _executeTokenTransfer(
        address _tokenAddress,
        address _safeAddress,
        address _recipient,
        uint256 _amount
    ) private {
        require(_recipient != address(0), "invalid recipient address");

        // Transfer data
        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _recipient,
            _amount
        );

        // Execute transfer
        require(
            SafeV2(payable(_safeAddress)).execTransactionFromModule(
                _tokenAddress,
                0,
                data,
                Enum.Operation.Call
            ),
            "Could not execute token transfer"
        );
    }

    /**
     * @dev Execute NFT transfer
     * 
     * @param _tokenAddress NFT contract address
     * @param _safeAddress Safe contract address
     * @param _tokenId NFT tokenId
     * @param _recipient Recipient address
     * @param _deadline Signature expiration time
     * @param _signatures Signature data
     */
    function nftTransfer(
        address _tokenAddress,
        address _safeAddress,
        uint256 _tokenId,
        address _recipient,
        uint256 _deadline,
        bytes memory _signatures
    ) public nonReentrant {
        require(_deadline >= block.timestamp, "expired deadline");
        require(_tokenAddress != address(0), "invalid token address");
        require(_safeAddress != address(0), "invalid safe address");
        require(_recipient != address(0), "invalid recipient address");

        bytes32 signatureData = keccak256(
            abi.encode(
                NFT_TRANSFER_TYPE_HASH,
                _tokenAddress,
                _safeAddress,
                _tokenId,
                _recipient,
                nonces[_safeAddress]++,
                _deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", getDomainSeparator(), signatureData)
        );

        SafeV2(payable(_safeAddress)).checkNSignatures(
            hash,
            abi.encodePacked(signatureData),
            _signatures,
            1 // Only 1 signer is required
        );

        // Transfer data
        bytes memory data = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            _safeAddress,
            _recipient,
            _tokenId
        );

        // Execute transfer
        require(
            SafeV2(payable(_safeAddress)).execTransactionFromModule(
                _tokenAddress,
                0,
                data,
                Enum.Operation.Call
            ),
            "Could not execute NFT transfer"
        );
    }

    /**
     * @notice Checks whether the signature provided is valid for the provided data and hash. Reverts otherwise.
     * @dev Since the EIP-1271 does an external call, be mindful of reentrancy attacks.
     * @param signatureData could be either a message hash or transaction hash
     * @param signatures Signature data that should be verified.
     *                   Can be packed ECDSA signature ({bytes32 r}{bytes32 s}{uint8 v}), contract signature (EIP-1271) or approved hash.
     * @param safe Safe contract address.
     * @param settingManager Setting manager contract address.
     */
    function checkSignatures(bytes32 signatureData, bytes memory signatures, SafeV2 safe,  ISettingManager settingManager) public view {
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;

        require(address(settingManager) != address(0), "not setting manager found");
        require(settingManager.viewWithdrawSigner().length > 0, "no withdraw signer found");

        // Number of signatures should equal the number of owners
        uint256 requiredSignatures = settingManager.viewWithdrawSigner().length + 1;
        require(signatures.length == requiredSignatures.mul(65), "invalid number of signatures");
        
        // Check each signature
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", getDomainSeparator(), signatureData)
        );
        
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        for (uint256 i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the Ethereum message prefix before applying ecrecover
                currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)), v - 4, r, s);
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(hash, v, r, s);
            }
            require(currentOwner > lastOwner && (settingManager.isWithdrawSigner(currentOwner) || safe.isOwner(currentOwner)), "invalid signer or not owner");
            lastOwner = currentOwner;
        }
    }
} 