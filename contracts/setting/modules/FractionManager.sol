// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title FeeManager
 * @notice Module for managing all fee-related configurations in the system including:
 * - Transaction fees for fraction exchanges
 * - Withdrawal fees
 * - NFT royalty fees (creator and owner)
 * @dev Uses basis points (1/1000000) for all fee calculations
 * Implements maximum fee rate limits (15% of denominator)
 */
import {SettingERROR} from "./SettingERROR.sol";
import {FractionConfig} from "../../interfaces/ISettingManager.sol";

abstract contract FractionManager is SettingERROR {

    FractionConfig internal _FractionConfig =
        FractionConfig({
            minVoteDuration: 1 days,
            maxVoteDuration: 28 days,
            votePercentage: 500001, // 50.0001%
            minAuctionDuration: 7 days,
            maxAuctionDuration: 168 days,
            bidIncreasePercentage: 10000, // 1%
            minPresaleDuration: 1 days,
            maxPresaleDuration: 28 days
        });

    event FractionConfigUpdated(
        uint64 minVoteDuration,
        uint64 maxVoteDuration,
        uint64 votePercentage,
        uint64 minAuctionDuration,
        uint64 maxAuctionDuration,
        uint64 bidIncreasePercentage,
        uint64 minPresaleDuration,
        uint64 maxPresaleDuration
    );

    function _fractionFeeDenominator() internal pure returns (uint64) {
        return 1_000_000; // 1e6 in uint64
    }

    function _fractionMaxFeeRate() internal pure returns (uint64) {
        return 1_000_000;
    }

    // FractionConfig Setters
    function _setFractionConfig(
        uint64 _minVoteDuration,
        uint64 _maxVoteDuration,
        uint64 _votePercentage,
        uint64 _minAuctionDuration,
        uint64 _maxAuctionDuration,
        uint64 _bidIncreasePercentage,
        uint64 _minPresaleDuration,
        uint64 _maxPresaleDuration
    ) internal {
        uint64 maxFeeRate = _fractionMaxFeeRate();
        if (_minVoteDuration > maxFeeRate) revert InvalidFeeRate(_minVoteDuration, maxFeeRate);
        if (_bidIncreasePercentage > maxFeeRate) revert InvalidFeeRate(_bidIncreasePercentage, maxFeeRate);
        _FractionConfig = FractionConfig({
            minVoteDuration: _minVoteDuration,
            maxVoteDuration: _maxVoteDuration,
            votePercentage: _votePercentage,
            minAuctionDuration: _minAuctionDuration,
            maxAuctionDuration: _maxAuctionDuration,
            bidIncreasePercentage: _bidIncreasePercentage,
            minPresaleDuration: _minPresaleDuration,
            maxPresaleDuration: _maxPresaleDuration
        });
        emit FractionConfigUpdated(
            _FractionConfig.minVoteDuration,
            _FractionConfig.maxVoteDuration,
            _FractionConfig.votePercentage,
            _FractionConfig.minAuctionDuration,
            _FractionConfig.maxAuctionDuration,
            _FractionConfig.bidIncreasePercentage,
            _FractionConfig.minPresaleDuration,
            _FractionConfig.maxPresaleDuration
        );
    }

    // Getters
    function getFractionConfig()
        external
        view
        returns (uint64, uint64, uint64, uint64, uint64, uint64, uint64, uint64, uint64)
    {
        return (
            _FractionConfig.minVoteDuration,
            _FractionConfig.maxVoteDuration,
            _FractionConfig.votePercentage,
            _FractionConfig.minAuctionDuration,
            _FractionConfig.maxAuctionDuration,
            _FractionConfig.bidIncreasePercentage,
            _FractionConfig.minPresaleDuration,
            _FractionConfig.maxPresaleDuration,
            _fractionFeeDenominator()
        );
    }

    // Get by struct
    function getFractionConfigStruct()
        external
        view
        returns (FractionConfig memory, uint64)
    {
        return (_FractionConfig, _fractionFeeDenominator());
    }

    uint256[8] private __gap;
}
