// SPDX-License-Identifier: MIT
/// @title Fraction Manager Contract
/// @notice Abstract contract for managing fraction-related configurations and contracts
/// @author Domain Team
pragma solidity ^0.8.22;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IFractionManager} from "../interfaces/IFractionManager.sol";

/// @title FractionManager
/// @notice Abstract contract that implements fraction management functionality
/// @dev This contract handles fraction configurations and maintains a whitelist of fragment contracts
abstract contract FractionManager is IFractionManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Storage slot constant for fraction storage
    bytes32 private constant FractionStorageLocal = keccak256("domain.setting.fraction");

    /// @notice Struct containing all fraction-related storage
    /// @dev This struct holds fraction configurations and a set of whitelisted fragment contracts
    struct FractionStorage {
        FractionConfig config;
        EnumerableSet.AddressSet fragmentContracts;
        address fragmentLogic;
        address fragmentSwapPairLogic;
    }

    /// @notice Gets the FractionStorage from a predefined storage slot
    /// @return fs Reference to the FractionStorage struct
    function _getFractionStorage() private pure returns (FractionStorage storage fs) {
        bytes32 slot = FractionStorageLocal;
        assembly {
            fs.slot := slot
        }
    }

    /// @notice Initializes the FractionManager with default values
    /// @dev Sets initial fraction configurations
    function __FractionManager_init(address _receiver) internal {
        _setFractionConfig(1 days, 28 days, 500001, 7 days, 168 days, 10000, 0, _receiver);
    }

    /// @notice Gets the current fraction configuration
    /// @return FractionConfig struct containing all fraction parameters
    function getFractionConfigStruct() public view returns (FractionConfig memory) {
        return _getFractionStorage().config;
    }

    /// @notice Checks if an address is in the fragment contracts whitelist
    /// @param _contractsAddress The address to check
    /// @return bool True if the address is whitelisted, false otherwise
    function isFragmentContracts(address _contractsAddress) public view virtual returns (bool) {
        return _getFractionStorage().fragmentContracts.contains(_contractsAddress);
    }

    function getFragmentLogic() public view virtual returns (address) {
        return _getFractionStorage().fragmentLogic;
    }

    function getFragmentSwapPairLogic() public view virtual returns (address) {
        return _getFractionStorage().fragmentSwapPairLogic;
    }

    /// @notice Gets the number of whitelisted fragment contracts
    /// @return uint256 The count of whitelisted fragment contracts
    function getFragmentContractsLength() public view virtual returns (uint256) {
        return _getFractionStorage().fragmentContracts.length();
    }

    /// @notice Gets a paginated list of whitelisted fragment contracts
    /// @param offset The starting index for pagination
    /// @param limit The maximum number of items to return
    /// @return address[] Array of whitelisted fragment contract addresses
    function getFragmentContractsPagination(uint256 offset, uint256 limit) public view returns (address[] memory) {
        FractionStorage storage fs = _getFractionStorage();
        uint256 total = fs.fragmentContracts.length();
        if (offset >= total) return new address[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = fs.fragmentContracts.at(i);
        }
        return result;
    }

    function _setFragmentLogic(address _logic) internal {
        _getFractionStorage().fragmentLogic = _logic;
        emit FragmentLogicUpdated(_logic);
    }

    function _setFragmentSwapPairLogic(address _logic) internal {
        _getFractionStorage().fragmentSwapPairLogic = _logic;
        emit FragmentSwapPairLogicUpdated(_logic);
    }

    /// @notice Sets fraction configuration parameters
    /// @dev Validates parameters before updating storage
    /// @param _minVoteDuration Minimum duration for voting
    /// @param _maxVoteDuration Maximum duration for voting
    /// @param _votePercentage Required percentage for vote approval
    /// @param _minAuctionDuration Minimum duration for auctions
    /// @param _maxAuctionDuration Maximum duration for auctions
    /// @param _bidIncreasePercentage Minimum bid increase percentage for auctions
    function _setFractionConfig(
        uint32 _minVoteDuration,
        uint32 _maxVoteDuration,
        uint32 _votePercentage,
        uint32 _minAuctionDuration,
        uint32 _maxAuctionDuration,
        uint32 _bidIncreasePercentage,
        uint32 _serviceCharge,
        address _serviceChargeReceiver
    ) internal {
        uint32 maxFeeRate = _fractionMaxFeeRate();
        if (_minVoteDuration > maxFeeRate || _bidIncreasePercentage > maxFeeRate) revert("Invalid fee rate");

        FractionStorage storage fs = _getFractionStorage();
        fs.config = FractionConfig({
            minVoteDuration: _minVoteDuration,
            maxVoteDuration: _maxVoteDuration,
            votePercentage: _votePercentage,
            minAuctionDuration: _minAuctionDuration,
            maxAuctionDuration: _maxAuctionDuration,
            bidIncreasePercentage: _bidIncreasePercentage,
            serviceCharge: _serviceCharge,
            serviceChargeReceiver: _serviceChargeReceiver,
            denominator: _fractionFeeDenominator()
        });
        emit FractionConfigUpdated(
            fs.config.minVoteDuration,
            fs.config.maxVoteDuration,
            fs.config.votePercentage,
            fs.config.minAuctionDuration,
            fs.config.maxAuctionDuration,
            fs.config.bidIncreasePercentage,
            fs.config.serviceCharge,
            fs.config.serviceChargeReceiver
        );
    }

    /// @notice Adds a contract to the fragment contracts whitelist
    /// @param _contractsAddress The address to add to the whitelist
    function _addFragmentContract(address _contractsAddress) internal {
        if (_contractsAddress == address(0)) revert("Invalid wallet address");
        FractionStorage storage fs = _getFractionStorage();
        if (fs.fragmentContracts.contains(_contractsAddress)) {
            revert("Already whitelisted");
        }
        fs.fragmentContracts.add(_contractsAddress);
        emit FragmentContractAdd(_contractsAddress);
    }

    /// @notice Removes a contract from the fragment contracts whitelist
    /// @param _contractsAddress The address to remove from the whitelist
    function _removeFragmentContract(address _contractsAddress) internal {
        FractionStorage storage fs = _getFractionStorage();
        if (!fs.fragmentContracts.contains(_contractsAddress)) {
            revert("Not whitelisted");
        }
        fs.fragmentContracts.remove(_contractsAddress);
        emit FragmentContractRemoved(_contractsAddress);
    }

    /// @notice Returns the fraction fee denominator used for rate calculations
    /// @dev All rates are per million (1_000_000)
    /// @return uint32 The denominator value (1_000_000)
    function _fractionFeeDenominator() internal pure returns (uint32) {
        return 1_000_000; // 1e6 in uint32
    }

    /// @notice Returns the maximum allowed fraction fee rate
    /// @dev Used to validate fee rate inputs
    /// @return uint32 The maximum allowed fee rate (1_000_000 or 100%)
    function _fractionMaxFeeRate() internal pure returns (uint32) {
        return 1_000_000;
    }
}
