// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;



struct FractionConfig {
    uint64 minVoteDuration; // 最小投票时长
    uint64 maxVoteDuration; // 最大投票时长
    uint64 votePercentage; // 投票百分百
    uint64 minAuctionDuration; // 最小拍卖时长
    uint64 maxAuctionDuration; // 最大拍卖时长
    uint64 bidIncreasePercentage; // 竞拍加价百分百
    uint64 minPresaleDuration; // 最小预售时长
    uint64 maxPresaleDuration; // 最大预售时长
}

interface ISettingManager {
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    function DEFAULT_ADMIN_ROLE() external returns (bytes32);
    function FEE_MANAGER_ROLE() external returns (bytes32);
    function SAFE_MANAGER_ROLE() external returns (bytes32);
    function TOKEN_MANAGER_ROLE() external returns (bytes32);
    function SIGNER_MANAGER_ROLE() external returns (bytes32);

    function UPGRADE_INTERFACE_VERSION() external returns (bytes32);

    function addToken(address token, TokenType tokenType) external;
    function removeToken(address token) external;
    function isTokenWhitelisted(address token) external view returns (bool);
    function getTokenType(address token) external view returns (TokenType);
    function viewWhitelistedTokensByType(TokenType tokenType) external view returns (address[] memory);

    function addSafeProxy(address safe) external;
    function removeSafeProxy(address safe) external;
    function isSafeWhitelisted(address safe) external view returns (bool);
    function viewCountWhitelistedSafes() external view returns (uint256);
    function viewWhitelistedSafes(uint256 cursor, uint256 size) external view returns (address[] memory, uint256);

    function addWithdrawSigner(address signer) external;
    function removeWithdrawSigner(address signer) external;
    function isWithdrawSigner(address signer) external view returns (bool);
    function viewCountWithdrawSigner() external view returns (uint256);
    function viewWithdrawSigner() external view returns (address[] memory);

    function addTransferAgentExchange(address exchange) external;
    function removeTransferAgentExchange(address exchange) external;
    function isTransferAgentExchange(address exchange) external view returns (bool);
    function viewCountTransferAgentExchange() external view returns (uint256);
    function viewTransferAgentExchange() external view returns (address[] memory);

    function setMarketFeeConfig(
        address _transactionFeeReceiver,
        uint64 _transactionFeeRate,
        uint64 _nftCreatorRoyaltyRate,
        uint64 _nftOwnerRoyaltyRate
    ) external;
    function setWithdrawalFeeReceiver(address _withdrawalFeeReceiver) external;
    function setSwapFeeConfig(address _swapFeeReceiver, uint64 _swapFee, uint64 _swapLpFee) external;
    
    function getMarketFeeConfig(
        address nftAddress,
        uint256 tokenId
    )
        external
        view
        returns (
            address transactionFeeReceiver,
            address nftCreatorRoyaltyReceiver,
            uint64 transactionFeeRate,
            uint64 nftCreatorRoyaltyRate,
            uint64 nftOwnerRoyaltyRate,
            uint64 denominator
        );
    function getMarketFees()
        external
        view
        returns (
            uint64 transactionFeeRate,
            uint64 nftCreatorRoyaltyRate,
            uint64 nftOwnerRoyaltyRate,
            uint64 denominator
        );
    function getWithdrawalFeeReceiver() external returns (address);
    function getSwapFeeConfig()
        external
        view
        returns (address swapFeeReceiver, uint64 swapFee, uint64 swapLpFee, uint64 denominator);
    function getSwapFees() external view returns (uint64 swapFee, uint64 swapLpFee, uint64 denominator);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function upgradeToAndCall(address newImplementation) external;
    function initialize(address _owner) external;
    function proxiableUUID() external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // Fraction
    function getFractionConfig()
        external
        view
        returns (uint64, uint64, uint64, uint64, uint64, uint64, uint64, uint64, uint64);
    function getFractionConfigStruct()
        external
        view
        returns (FractionConfig memory, uint64);
}
