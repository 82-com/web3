// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IVerifySignatures {
    function verifySignatures(bytes32 dataHash, bytes[] calldata signatures) external view returns (bool);
}
