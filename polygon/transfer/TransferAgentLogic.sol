// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Importing necessary OpenZeppelin contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITransferAgent} from "./interfaces/ITransferAgent.sol";
import {ITransferAgentManager} from "../setting/interfaces/ITransferAgentManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";

/**
 * @title TransferAgentLogic
 * @dev A contract that acts as a transfer agent for ERC20 and ERC721 tokens with whitelisted exchanges
 * @notice This contract is upgradeable using UUPS pattern and owned by an address
 */
contract TransferAgentLogic is ITransferAgent, OwnableUpgradeable, UUPSUpgradeable {
    // Using SafeERC20 for safe token transfers
    using SafeERC20 for IERC20;

    // Address of the setting manager contract
    address public settingManagerAddress;

    /**
     * @dev Modifier to restrict access to whitelisted exchanges only
     */
    modifier onlyWhitelisted() {
        if (
            !ITransferAgentManager(settingManagerAddress).isTransferAgentExchange(msg.sender) &&
            !IFractionManager(settingManagerAddress).isFragmentContracts(msg.sender)
        ) revert("caller is not a whitelisted exchange");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /**
     * @dev Constructor that disables initializers to prevent initialization of the implementation contract
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the initial owner
     * @param initialOwner The address that will be the initial owner of the contract
     */
    function initialize(address initialOwner, address _settingManagerAddress) public virtual initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        settingManagerAddress = _settingManagerAddress;
    }

    /**
     * @dev Authorizes upgrades to new implementations (UUPS pattern)
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Transfers ERC20 tokens between addresses
     * @param _currency Address of the ERC20 token contract
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
    ) external virtual onlyWhitelisted {
        _transferERC20(_transferType, _currency, _from, _to, _amount);
    }

    function batchTransferERC20(TransferERC20Params[] calldata params) external virtual onlyWhitelisted {
        for (uint256 i = 0; i < params.length; i++) {
            _transferERC20(params[i].transferType, params[i].currency, params[i].from, params[i].to, params[i].amount);
        }
    }

    /**
     * @notice Transfers ERC721 tokens between addresses
     * @dev Only callable by whitelisted exchanges
     * @param _nftAddress Address of the ERC721 token contract
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
    ) external virtual onlyWhitelisted {
        _transferERC721(_transferType, _nftAddress, _nftTokenId, _from, _to);
    }

    function batchTransferERC721(TransferERC721Params[] calldata params) external virtual onlyWhitelisted {
        for (uint256 i = 0; i < params.length; i++) {
            _transferERC721(
                params[i].transferType,
                params[i].nftAddress,
                params[i].nftTokenId,
                params[i].from,
                params[i].to
            );
        }
    }

    /**
     * @notice Triggers ERC20 transfer event without actual transfer
     * @dev Used to log transfer events when actual token transfer is handled elsewhere
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
    ) external virtual onlyWhitelisted {
        emit ERC20Transferred(_transferType, _currency, _from, _to, _amount);
    }

    /**
     * @notice Triggers ERC721 transfer event without actual transfer
     * @dev Used to log transfer events when actual NFT transfer is handled elsewhere
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
    ) external virtual onlyWhitelisted {
        emit ERC721Transferred(_transferType, _nftAddress, _from, _to, _nftTokenId);
    }

    function _transferERC20(
        ERC20TransferType _transferType,
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) private {
        IERC20 erc20 = IERC20(_currency);
        emit ERC20Transferred(_transferType, _currency, _from, _to, _amount);
        erc20.safeTransferFrom(_from, _to, _amount);
    }

    function _transferERC721(
        ERC721TransferType _transferType,
        address _nftAddress,
        uint256 _nftTokenId,
        address _from,
        address _to
    ) private {
        IERC721 nft = IERC721(_nftAddress);
        emit ERC721Transferred(_transferType, _nftAddress, _from, _to, _nftTokenId);
        nft.safeTransferFrom(_from, _to, _nftTokenId);
    }

    uint256[49] private __gap;
}
