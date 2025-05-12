// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Importing necessary OpenZeppelin contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface ISettingManager {
    function isTransferAgentExchange(address exchange) external view returns (bool);
}

/**
 * @title TransferAgentV1
 * @dev A contract that acts as a transfer agent for ERC20 and ERC721 tokens with whitelisted exchanges
 * @notice This contract is upgradeable using UUPS pattern and owned by an address
 */
contract TransferAgentV1 is UUPSUpgradeable, OwnableUpgradeable {
    // Events
    event ERC20Transferred(address indexed currency, address from, address to, uint256 amount);
    event ERC721Transferred(address indexed nft, address from, address to, uint256 tokenId);

    // Using SafeERC20 for safe token transfers
    using SafeERC20 for IERC20;

    // Custom errors
    error ERROR_NotWhitelistExchange();

    // Address of the setting manager contract
    address public settingManagerAddress;

    /**
     * @dev Modifier to restrict access to whitelisted exchanges only
     */
    modifier onlyWhitelisted() {
        if (!ISettingManager(settingManagerAddress).isTransferAgentExchange(msg.sender)) {
            revert ERROR_NotWhitelistExchange();
        }
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
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) external virtual onlyWhitelisted {
        IERC20 erc20 = IERC20(_currency);

        emit ERC20Transferred(_currency, _from, _to, _amount);

        erc20.safeTransferFrom(_from, _to, _amount);
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
        address _nftAddress,
        uint256 _nftTokenId,
        address _from,
        address _to
    ) external virtual onlyWhitelisted {
        IERC721 nft = IERC721(_nftAddress);

        emit ERC721Transferred(_nftAddress, _from, _to, _nftTokenId);

        nft.safeTransferFrom(_from, _to, _nftTokenId);
    }

    uint256[49] private __gap;
}
