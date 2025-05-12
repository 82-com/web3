// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IDomainNFT {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
    function initialize(address _freezeManager, address _settingManager) external;

    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 amount);

    function setBaseURI(string calldata baseURI) external;

    function frozenTokenId(uint256 _tokenId) external;

    function unfreezeTokenId(uint256 _tokenId) external;

    function isFrozenTokenId(uint256 _tokenId) external view returns (bool);

    function mint(address to) external returns (uint256);

    function burn(uint256 _tokenId) external;

    function batchMint(MintParams[] calldata params) external;

    function getTokenIdsByCurator(address curator) external view returns (uint256[] memory);

    function viewRoleMember(
        bytes32 role,
        uint256 cursor,
        uint256 size
    ) external view returns (address[] memory, uint256);

    struct MintParams {
        address to;
        uint256 tokenNum;
    }
}
