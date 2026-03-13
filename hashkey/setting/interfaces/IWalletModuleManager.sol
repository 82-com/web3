// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IWalletModuleManager {
    event WalletModuleAdd(address _moduleAddress);
    event WalletModuleRemoved(address _moduleAddress);

    function isWalletModule(address _moduleAddress) external view returns (bool);

    function getWalletModuleSetLength() external view returns (uint256);

    function getWalletModuleSet() external view returns (address[] memory);

    function addWalletModule(address _moduleAddress) external;

    function removeWalletModule(address _moduleAddress) external;
}
