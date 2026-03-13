// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Importing necessary OpenZeppelin upgradeable contracts
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IDomainNFT} from "./interfaces/IDomainNFT.sol";
import {IFeesManager} from "../setting/interfaces/IFeesManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";

/**
 * @title DomainNFTLogic
 * @dev An upgradeable ERC721 token contract with:
 * - Enumerable functionality
 * - Burnable capability
 * - Role-based access control
 * - UUPS upgrade pattern
 * - Royalty support (ERC2981)
 * - Freezing mechanism for tokens
 * @notice This contract represents domain name NFTs with advanced management features
 */
contract DomainNFTLogic is
    IDomainNFT,
    ERC721EnumerableUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    ERC2981Upgradeable
{
    using EnumerableSet for EnumerableSet.UintSet;
    // Role definitions
    bytes32 public constant FROZEN_ROLE = keccak256("FROZEN_ROLE");

    // Token management
    uint256 private _currendTokenId; // Counter for token IDs
    string private _baseURI_; // Base URI for token metadata
    mapping(uint256 => bool) public isFrozenTokenId_discard; // Tracks frozen tokens
    mapping(uint256 => address) public minters; // Maps tokenId to minter address

    // External contract reference
    address public settingManager; // Address of the SettingManager contract
    // Subsequently added
    EnumerableSet.UintSet frozenTokenIds; // Tracks frozen token IDs

    modifier onlyMultiSignatureWallet() {
        if (!IMultiSignatureWalletManager(settingManager).isMultiSignatureWallet(msg.sender)) revert("Invalid caller");
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
        IFeesManager.MarketFees memory marketFees = IFeesManager(settingManager).getMarketFeesStruct();
        uint256 royaltyAmount = (salePrice * marketFees.transactionFeeRate) / marketFees.denominator;
        return (marketFees.transactionFeeReceiver, royaltyAmount);
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

    function isFrozenTokenId(uint256 _tokenId) public view returns (bool) {
        return frozenTokenIds.contains(_tokenId);
    }

    /**
     * @notice Freezes a token, preventing transfers
     * @dev Only callable by freeze role
     * @param _tokenId ID of token to freeze
     */
    function frozenTokenId(uint256 _tokenId) public onlyRole(FROZEN_ROLE) {
        if (isFrozenTokenId(_tokenId)) revert("Token already frozen");
        frozenTokenIds.add(_tokenId);
        emit FrozenNFT(_tokenId);
    }

    /**
     * @notice Unfreezes a token, allowing transfers
     * @dev Only callable by freeze role
     * @param _tokenId ID of token to unfreeze
     */
    function unfreezeTokenId(uint256 _tokenId) public onlyRole(FROZEN_ROLE) {
        if (!isFrozenTokenId(_tokenId)) revert("Token not frozen");
        frozenTokenIds.remove(_tokenId);
        emit UnfreezeNFT(_tokenId);
    }

    function freezeTokenIds() public view returns (uint256[] memory) {
        return frozenTokenIds.values();
    }

    /**
     * @dev Authorizes contract upgrades (UUPS pattern)
     * @param newImplementation Address of new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _mintById(
        IMultiSignatureWalletManager mswm,
        address minter,
        address to,
        uint256 id,
        string calldata domain
    ) private {
        if (!mswm.isMultiSignatureWallet(to)) revert("Invalid receiver");
        _safeMint(to, id);
        if (minters[id] == address(0)) {
            if (minter == address(0)) {
                minters[id] = to;
            } else {
                if (!mswm.isMultiSignatureWallet(minter)) revert("Invalid minter");
                minters[id] = minter;
            }
            emit MintDomain(id, minters[id], to, domain);
        }
    }

    function batchMintById(MintByIdParams[] calldata params) external onlyMultiSignatureWallet {
        IMultiSignatureWalletManager mswm = IMultiSignatureWalletManager(settingManager);
        for (uint256 i = 0; i < params.length; ) {
            _mintById(mswm, params[i].minter, params[i].to, params[i].tokenId, params[i].domain);
            unchecked {
                ++i;
            }
        }
    }

    function batchSetMinters(
        uint256[] calldata tokenIds,
        address[] calldata _minters
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenIds.length == _minters.length, "Invalid input");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            minters[tokenIds[i]] = _minters[i];
        }
    }

    function _burn(uint256 tokenId, string calldata reason) private {
        super._checkAuthorized(super._ownerOf(tokenId), _msgSender(), tokenId);
        super._burn(tokenId);
        emit BurnDomain(tokenId, reason);
    }

    function batchBurn(BurnParams[] calldata params) external {
        for (uint256 i = 0; i < params.length; ) {
            _burn(params[i].tokenId, params[i].reason);
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

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning.
     * @dev Overridden to add frozen token check
     * @param to The recipient address
     * @param tokenId The token ID being transferred
     * @param auth The authorized address initiating the transfer
     * @return address The previous owner address
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721EnumerableUpgradeable) returns (address) {
        if (isFrozenTokenId(tokenId)) revert("Token is frozen");
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Increases an account's balance
     * @dev Overridden to maintain consistency with enumerable extension
     * @param account The account whose balance to increase
     * @param value The amount to increase by
     */
    function _increaseBalance(address account, uint128 value) internal override(ERC721EnumerableUpgradeable) {
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
        override(ERC721EnumerableUpgradeable, AccessControlEnumerableUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[44] private __gap;
}
