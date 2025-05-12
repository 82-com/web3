// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Importing necessary OpenZeppelin upgradeable contracts
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {ISettingManager} from "../interfaces/ISettingManager.sol";

/**
 * @title DomainNFTV3
 * @dev An upgradeable ERC721 token contract with:
 * - Enumerable functionality
 * - Burnable capability
 * - Role-based access control
 * - UUPS upgrade pattern
 * - Royalty support (ERC2981)
 * - Freezing mechanism for tokens
 * @notice This contract represents domain name NFTs with advanced management features
 */
contract DomainNFTV3 is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable,
    ERC2981Upgradeable
{
    /**
     * @dev Struct for batch minting parameters
     * @param to Recipient address
     * @param tokenNum Number of tokens to mint
     */
    struct MintParams {
        address to;
        uint256 tokenNum;
    }

    // Role definitions
    bytes32 public constant FROZEN_ROLE = keccak256("FROZEN_ROLE");

    // Token management
    uint256 private _currendTokenId; // Counter for token IDs
    string private _baseURI_; // Base URI for token metadata
    mapping(uint256 => bool) public isFrozenTokenId; // Tracks frozen tokens
    mapping(uint256 => address) public minters; // Maps tokenId to minter address

    // External contract reference
    address public settingManager; // Address of the SettingManager contract

    // Events
    event FrozenNFT(uint256 tokenId);
    event UnfreezeNFT(uint256 tokenId);

    // Custom errors
    error ERROR_NFT_FROZEN();
    error ERROR_NFT_NOT_FROZEN();
    error ERROR_NFT_NOT_MINTED();
    error ERROR_ADMIN_ROLE_EMPTY();
    error ERROR_ONLY_SAFE_PROXY();

    modifier onlySafeProxy() {
        try ISettingManager(settingManager).isSafeWhitelisted(msg.sender) returns (bool isWhitelisted) {
            if (!isWhitelisted) revert ERROR_ONLY_SAFE_PROXY();
        } catch {
            revert ERROR_ONLY_SAFE_PROXY();
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
     * @notice Initializes the contract
     * @dev Sets up roles, base contracts, and initial configuration
     * @param _freezeManager Address to be granted freeze role
     * @param _settingManager Address of the SettingManager contract
     */
    function initialize(address _admin, address _freezeManager, address _settingManager) public initializer {
        __ERC721_init("DNS", "DNS");
        __ERC721Enumerable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __ERC2981_init();
        __UUPSUpgradeable_init();

        // Grant initial roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FROZEN_ROLE, _freezeManager);

        settingManager = _settingManager;
    }

    /**
     * @notice Returns royalty information for token sales
     * @dev Implements ERC2981 royalty standard
     * @param salePrice Sale price of the token
     * @return receiver Address to receive royalties
     * @return amount Royalty amount in wei
     */
    function royaltyInfo(uint256, uint256 salePrice) public view override returns (address receiver, uint256 amount) {
        (address _transactionFeeReceiver, , uint64 _transactionFeeRate, , , uint64 denominator) = ISettingManager(
            settingManager
        ).getMarketFeeConfig(address(0), 0);
        uint256 royaltyAmount = (salePrice * _transactionFeeRate) / denominator;

        return (_transactionFeeReceiver, royaltyAmount);
    }

    /**
     * @notice Returns base URI for token metadata
     * @dev Internal view function override
     * @return Current base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURI_;
    }

    /**
     * @notice Sets base URI for token metadata
     * @dev Only callable by admin role
     * @param baseURI New base URI string
     */
    function setBaseURI(string calldata baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseURI_ = baseURI;
    }

    /**
     * @notice Freezes a token, preventing transfers
     * @dev Only callable by freeze role
     * @param _tokenId ID of token to freeze
     */
    function frozenTokenId(uint256 _tokenId) public onlyRole(FROZEN_ROLE) {
        if (_tokenId > _currendTokenId) {
            revert ERROR_NFT_NOT_MINTED();
        }
        if (isFrozenTokenId[_tokenId]) {
            revert ERROR_NFT_FROZEN();
        }
        isFrozenTokenId[_tokenId] = true;
        emit FrozenNFT(_tokenId);
    }

    /**
     * @notice Unfreezes a token, allowing transfers
     * @dev Only callable by freeze role
     * @param _tokenId ID of token to unfreeze
     */
    function unfreezeTokenId(uint256 _tokenId) public onlyRole(FROZEN_ROLE) {
        if (!isFrozenTokenId[_tokenId]) {
            revert ERROR_NFT_NOT_FROZEN();
        }
        isFrozenTokenId[_tokenId] = false;
        emit UnfreezeNFT(_tokenId);
    }

    /**
     * @dev Authorizes contract upgrades (UUPS pattern)
     * @param newImplementation Address of new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Mints a new token to specified address
     * @param to Recipient address
     * @return tokenId ID of newly minted token
     */
    function mint(address to) public onlySafeProxy returns (uint256) {
        uint256 tokenId = ++_currendTokenId;
        _safeMint(to, tokenId);
        minters[tokenId] = to;
        return tokenId;
    }

    /**
     * @notice Batch mints tokens to multiple recipients
     * @param params Array of MintParams specifying recipients and amounts
     */
    function batchMint(MintParams[] calldata params) external onlySafeProxy {
        for (uint256 i = 0; i < params.length; ) {
            for (uint256 j = 0; j < params[i].tokenNum; ) {
                mint(params[i].to);
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Gets all token IDs owned by a curator
     * @param curator Address to query
     * @return Array of token IDs owned by curator
     */
    function getTokenIdsByCurator(address curator) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(curator);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(curator, i);
        }
        return tokenIds;
    }

    // The following functions are overrides required by Solidity.

    /**
     * @dev Updates token ownership with freeze check
     * @param to New owner address
     * @param tokenId Token ID being transferred
     * @param auth Authorized address
     * @return address of the previous owner
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        if (isFrozenTokenId[tokenId]) {
            revert ERROR_NFT_FROZEN();
        }
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Increases balance of an account
     * @param account Address whose balance to increase
     * @param value Amount to increase by
     */
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    /**
     * @notice Checks interface support
     * @dev Combines interface checks from all parent contracts
     * @param interfaceId Interface identifier
     * @return bool Whether interface is supported
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    uint256[44] private __gap;
}
