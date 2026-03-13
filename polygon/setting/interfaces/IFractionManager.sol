// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IFractionManager {
    struct FractionConfig {
        uint32 minVoteDuration; // min voting duration
        uint32 maxVoteDuration; // max voting duration
        uint32 votePercentage; // vote percentage
        uint32 minAuctionDuration; // min auction duration
        uint32 maxAuctionDuration; // max auction duration
        uint32 bidIncreasePercentage; // bid increase percentage
        uint32 serviceCharge; // service charge
        address serviceChargeReceiver; // service charge receiver
        uint32 denominator;
    }

    event FractionConfigUpdated(
        uint32 minVoteDuration,
        uint32 maxVoteDuration,
        uint32 votePercentage,
        uint32 minAuctionDuration,
        uint32 maxAuctionDuration,
        uint32 bidIncreasePercentage,
        uint32 serviceCharge,
        address serviceChargeReceiver
    );
    event FragmentContractAdd(address _address);
    event FragmentContractRemoved(address _address);
    event FragmentLogicUpdated(address _address);
    event FragmentSwapPairLogicUpdated(address _address);

    function getFractionConfigStruct() external view returns (FractionConfig memory);

    function isFragmentContracts(address _address) external view returns (bool);

    function getFragmentLogic() external view returns (address);

    function getFragmentSwapPairLogic() external view returns (address);

    function getFragmentContractsLength() external view returns (uint256);

    function getFragmentContractsPagination(uint256 offset, uint256 limit) external view returns (address[] memory);

    function setFragmentLogic(address _logic) external;

    function setFragmentSwapPairLogic(address _logic) external;

    function setFractionConfig(
        uint32 _minVoteDuration,
        uint32 _maxVoteDuration,
        uint32 _votePercentage,
        uint32 _minAuctionDuration,
        uint32 _maxAuctionDuration,
        uint32 _bidIncreasePercentage,
        uint32 _serviceCharge,
        address _serviceChargeReceiver
    ) external;

    function addFragmentContract(address _address) external;

    function removeFragmentContract(address _address) external;
}
