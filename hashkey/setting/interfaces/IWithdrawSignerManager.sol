// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IWithdrawSignerManager {
    event WithdrawSignerAdd(address signer);
    event WithdrawSignerRemoved(address signer);
    event SignerThresholdChanged(uint256 threshold);

    function isWithdrawSigner(address) external view returns (bool);

    function getWithdrawSignerSet() external view returns (address[] memory);

    function getSignerThreshold() external view returns (uint256);

    function addWithdrawSigner(address signer) external;

    function removeWithdrawSigner(address signer) external;

    function setSignerThreshold(uint256 threshold) external;
}
