// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title FeeManager
 * @notice Module for managing all fee-related configurations in the system including:
 * - Transaction fees for domain exchanges
 * - Withdrawal fees
 * - NFT royalty fees (creator and owner)
 * @dev Uses basis points (1/1000000) for all fee calculations
 * Implements maximum fee rate limits (15% of denominator)
 */
import {SettingERROR} from "./SettingERROR.sol";

interface IDomainNFT {
    function minters(uint256 tokenId) external view returns (address);
}

abstract contract FeeManager is SettingERROR {
    struct MarketFees {
        address transactionFeeReceiver;
        uint64 transactionFeeRate;
        uint64 nftCreatorRoyaltyRate;
        uint64 nftOwnerRoyaltyRate;
        uint64 denominator;
    }

    struct SwapFees {
        address swapFeeReceiver;
        uint64 swapFee;
        uint64 swapLpFee;
        uint64 denominator;
    }

    MarketFees internal _marketFees =
        MarketFees({
            transactionFeeReceiver: address(0),
            transactionFeeRate: 0,
            nftCreatorRoyaltyRate: 0,
            nftOwnerRoyaltyRate: 0,
            denominator: _feeDenominator()
        });

    address internal _withdrawalFeeReceiver;

    SwapFees internal _swapFees =
        SwapFees({swapFeeReceiver: address(0), swapFee: 0, swapLpFee: 0, denominator: _feeDenominator()});

    event MarketFeesUpdated(
        address transactionFeeReceiver,
        uint64 transactionFeeRate,
        uint64 nftCreatorRoyaltyRate,
        uint64 nftOwnerRoyaltyRate,
        uint64 denominator
    );
    event WithdrawalFeeReceiverUpdated(address withdrawalFeeReceiver);
    event SwapFeesUpdated(address swapFeeReceiver, uint64 swapFee, uint64 swapLpFee, uint64 denominator);

    function _feeDenominator() internal pure returns (uint64) {
        return 1_000_000; // 1e6 in uint64
    }

    function _maxFeeRate() internal pure returns (uint64) {
        return 150_000;
    }

    // MarketFees Setters
    function _setMarketFeeConfig(
        address _transactionFeeReceiver,
        uint64 _transactionFeeRate,
        uint64 _nftCreatorRoyaltyRate,
        uint64 _nftOwnerRoyaltyRate
    ) internal nonZeroAddress(_transactionFeeReceiver) {
        uint64 maxFeeRate = _maxFeeRate();
        if (_transactionFeeRate > maxFeeRate) revert InvalidFeeRate(_transactionFeeRate, maxFeeRate);
        if (_nftCreatorRoyaltyRate > maxFeeRate) revert InvalidFeeRate(_nftCreatorRoyaltyRate, maxFeeRate);
        if (_nftOwnerRoyaltyRate > maxFeeRate) revert InvalidFeeRate(_nftOwnerRoyaltyRate, maxFeeRate);
        _marketFees = MarketFees({
            transactionFeeReceiver: _transactionFeeReceiver,
            transactionFeeRate: _transactionFeeRate,
            nftCreatorRoyaltyRate: _nftCreatorRoyaltyRate,
            nftOwnerRoyaltyRate: _nftOwnerRoyaltyRate,
            denominator: _feeDenominator()
        });
        emit MarketFeesUpdated(
            _marketFees.transactionFeeReceiver,
            _marketFees.transactionFeeRate,
            _marketFees.nftCreatorRoyaltyRate,
            _marketFees.nftOwnerRoyaltyRate,
            _marketFees.denominator
        );
    }

    // WithdrawalFees Setters
    function _setWithdrawalFeeReceiver(address _newReceiver) internal nonZeroAddress(_newReceiver) {
        _withdrawalFeeReceiver = _newReceiver;
        emit WithdrawalFeeReceiverUpdated(_withdrawalFeeReceiver);
    }

    // SwapFees Setters
    function _setSwapFeeConfig(
        address _swapFeeReceiver,
        uint64 _swapFee,
        uint64 _swapLpFee
    ) internal nonZeroAddress(_swapFeeReceiver) {
        uint64 maxFeeRate = _maxFeeRate();
        if (_swapFee > maxFeeRate) revert InvalidFeeRate(_swapFee, maxFeeRate);
        if (_swapLpFee > maxFeeRate) revert InvalidFeeRate(_swapLpFee, maxFeeRate);
        _swapFees = SwapFees({
            swapFeeReceiver: _swapFeeReceiver,
            swapFee: _swapFee,
            swapLpFee: _swapLpFee,
            denominator: _feeDenominator()
        });
        emit SwapFeesUpdated(_swapFees.swapFeeReceiver, _swapFees.swapFee, _swapFees.swapLpFee, _swapFees.denominator);
    }

    // Getters
    function getMarketFeeConfig(
        address nftAddress,
        uint256 tokenId
    ) external view returns (address, address, uint64, uint64, uint64, uint64) {
        address nftMinter = address(0);
        if (nftAddress != address(0) && nftAddress.code.length > 0) {
            try IDomainNFT(nftAddress).minters(tokenId) returns (address minter) {
                nftMinter = minter;
            } catch {}
        }
        return (
            _marketFees.transactionFeeReceiver,
            nftMinter,
            _marketFees.transactionFeeRate,
            _marketFees.nftCreatorRoyaltyRate,
            _marketFees.nftOwnerRoyaltyRate,
            _marketFees.denominator
        );
    }

    function getMarketFees() external view returns (uint64, uint64, uint64, uint64) {
        return (
            _marketFees.transactionFeeRate,
            _marketFees.nftCreatorRoyaltyRate,
            _marketFees.nftOwnerRoyaltyRate,
            _marketFees.denominator
        );
    }

    function getWithdrawalFeeReceiver() external view returns (address) {
        return _withdrawalFeeReceiver;
    }

    function getSwapFeeConfig() external view returns (address, uint64, uint64, uint64) {
        return (_swapFees.swapFeeReceiver, _swapFees.swapFee, _swapFees.swapLpFee, _swapFees.denominator);
    }

    function getSwapFees() external view returns (uint64, uint64, uint64) {
        return (_swapFees.swapFee, _swapFees.swapLpFee, _swapFees.denominator);
    }

    uint256[6] private __gap;
}
