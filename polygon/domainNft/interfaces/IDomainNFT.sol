// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IDomainNFT {
    struct MintByIdParams {
        address to;
        uint256 tokenId;
        address minter;
        string domain;
    }

    struct BurnParams {
        uint256 tokenId;
        string reason;
    }

    event FrozenNFT(uint256 tokenId);
    event UnfreezeNFT(uint256 tokenId);
    event MintDomain(uint256 tokenId, address minter, address to, string domain);
    event BurnDomain(uint256 tokenId, string reason);

    function minters(uint256 id) external view returns (address);

    function frozenTokenId(uint256 _tokenId) external;

    function unfreezeTokenId(uint256 _tokenId) external;

    function isFrozenTokenId(uint256 _tokenId) external view returns (bool);

    function batchMintById(MintByIdParams[] calldata params) external;

    function batchBurn(BurnParams[] calldata params) external;
}
