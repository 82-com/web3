// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

pragma experimental ABIEncoderV2;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DomainFractionProxy} from "./DomainFractionProxy.sol";
import {IDomainFraction} from "./interfaces/IDomainFraction.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {ITransferAgent} from "../transfer/interfaces/ITransferAgent.sol";
import {ITokenManager} from "../setting/interfaces/ITokenManager.sol";
import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";

/// @title Domain Fraction Factory Contract
/// @notice Factory contract for creating Domain Fraction proxies
/// @dev Handles the creation of fraction contracts for ERC721 tokens
contract DomainFractionFactory is ReentrancyGuard {
    /// @notice Address of the Setting Manager contract
    /// @dev Used to access system settings and configurations
    address public immutable settingManager;

    /// @notice Address of the Transfer Agent contract
    /// @dev Handles token transfers and related operations
    address public immutable transferAgent;

    address public immutable proxyContractLogicAddress;

    /// @notice Initializes the factory with required contract addresses
    /// @dev Sets up the factory with core system contracts
    /// @param initiaSettingManager Address of the Setting Manager contract
    /// @param initiaTransferAgent Address of the Transfer Agent contract
    constructor(address initiaSettingManager, address initiaTransferAgent) {
        require(initiaSettingManager != address(0), "settingManager is zero address");
        require(initiaTransferAgent != address(0), "transferAgent is zero address");
        settingManager = initiaSettingManager;
        transferAgent = initiaTransferAgent;
        proxyContractLogicAddress = IFractionManager(settingManager).getFragmentLogic();
    }

    /// @notice Modifier to check if an address is a valid multi-signature wallet
    /// @dev Reverts if the address is not a registered multi-signature wallet
    /// @param _targetAddr Address to check for multi-signature wallet status
    modifier isMultiSignatureWallet(address _targetAddr) {
        if (!IMultiSignatureWalletManager(settingManager).isMultiSignatureWallet(_targetAddr))
            revert("Not proxy wallet");
        _;
    }

    /// @notice Emitted when a new fraction contract is created
    /// @param curator Address of the curator who created the fraction contract
    /// @param erc721 Address of the ERC721 token being fractionated
    /// @param erc721TokenId Token ID of the ERC721 being fractionated
    /// @param fraction Address of the newly created fraction contract
    /// @param erc20TotalSupply Total supply of the ERC20 fraction tokens
    event Fragmentization(
        address curator,
        address erc721,
        uint256 erc721TokenId,
        address indexed fraction,
        uint256 erc20TotalSupply
    );

    /// @notice Creates a new fraction contract for an ERC721 token
    /// @dev Handles the entire fractionation process including validation and token transfer
    /// @param config Configuration for the ERC20 fraction tokens
    /// @param info Information about the ERC721 token to be fractionated
    /// @param salt salt
    /// @return fraction Address of the newly created fraction proxy contract
    function fragmentization(
        IDomainFraction.ERC20Config memory config,
        IDomainFraction.ERC721Info memory info,
        bytes32 salt
    ) public nonReentrant isMultiSignatureWallet(msg.sender) returns (address fraction) {
        require(IERC721(info.erc721Token).ownerOf(info.tokenId) == msg.sender, "not owner");
        require(ITokenManager(settingManager).isTokenWhitelisted(info.priceCurrency), "currency not whitelisted");
        require(ITokenManager(settingManager).isTokenWhitelisted(info.erc721Token), "erc721 not whitelisted");

        bytes memory bytecode = type(DomainFractionProxy).creationCode;
        bytes memory initData = abi.encode(proxyContractLogicAddress, settingManager, transferAgent, config, info);
        bytes memory creationCode = abi.encodePacked(bytecode, initData);

        assembly {
            fraction := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }

        require(fraction != address(0), "create2 failed");

        emit Fragmentization(msg.sender, info.erc721Token, info.tokenId, fraction, config.originalTotalSupply);
        IFractionManager(settingManager).addFragmentContract(fraction);

        ITransferAgent(transferAgent).transferERC721(
            ITransferAgent.ERC721TransferType.DomainDebris,
            info.erc721Token,
            info.tokenId,
            msg.sender,
            fraction
        );
    }

    function predictProxyAddressWithSalt(
        IDomainFraction.ERC20Config memory config,
        IDomainFraction.ERC721Info memory info,
        bytes32 salt
    ) external view returns (address) {
        bytes memory bytecode = type(DomainFractionProxy).creationCode;
        bytes memory initData = abi.encode(proxyContractLogicAddress, settingManager, transferAgent, config, info);
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(abi.encodePacked(bytecode, initData)))
        );
        return address(uint160(uint256(hash)));
    }
}
