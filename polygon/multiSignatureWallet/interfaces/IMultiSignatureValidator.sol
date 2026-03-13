// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMultiSignatureValidator {
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ThresholdChanged(uint256 newThreshold);

    // view functions
    function getSignerCount() external view returns (uint256);

    function getSigners() external view returns (address[] memory);

    function isSigner(address) external view returns (bool);

    function getThreshold() external view returns (uint256);
}
