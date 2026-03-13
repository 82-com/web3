// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IFeesManager {
    struct MarketFees {
        address transactionFeeReceiver;
        uint32 transactionFeeRate;
        uint32 nftCreatorFirstRoyaltyRate;
        uint32 nftCreatorRoyaltyRate;
        uint32 buyerInviterRoyaltyRate;
        uint32 sellerInviterRoyaltyRate;
        uint32 denominator;
    }

    struct SwapFees {
        address swapFeeReceiver;
        uint32 swapFee;
        uint32 swapLpFee;
        uint32 denominator;
    }

    struct OrderBookFees {
        address orderBookFeeReceiver;
        uint32 makerFee;
        uint32 takerFee;
        uint32 denominator;
    }

    // getters

    function getMarketFeesStruct() external view returns (MarketFees memory);

    function getSwapFeesStruct() external view returns (SwapFees memory);

    function getOrderBookFeesStruct() external view returns (OrderBookFees memory);

    function getWithdrawalFeeReceiver() external view returns (address);

    function getDomainExpenseReceiver() external view returns (address);

    // setters
    function setMarketFees(
        address transactionFeeReceiver,
        uint32 transactionFeeRate,
        uint32 nftCreatorFirstRoyaltyRate,
        uint32 nftCreatorRoyaltyRate,
        uint32 buyerInviterRoyaltyRate,
        uint32 sellerInviterRoyaltyRate
    ) external;

    function setSwapFees(address swapFeeReceiver, uint32 swapFee, uint32 swapLpFee) external;

    function setOrderBookFees(address orderBookFeeReceiver, uint32 makerFee, uint32 takerFee) external;

    function setWithdrawalFeeReceiver(address receiver) external;

    function setDomainExpenseReceiver(address receiver) external;
}
