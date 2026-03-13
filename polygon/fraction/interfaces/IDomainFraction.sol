//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IDomainFraction {
    struct ERC20Config {
        string name;
        string symbol;
        uint256 originalTotalSupply;
        address initalReceiver;
    }
    struct ERC721Info {
        address erc721Token;
        uint256 tokenId;
        address priceCurrency;
        uint256 reservePrice;
        uint256 voteDuration;
        uint256 auctionDuration;
        uint256 auctionDurationAdd;
    }
}
