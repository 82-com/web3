// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IAdvancedContractFactory {
    function createContractWithSalt(
        bytes memory bytecode,
        bytes memory constructorArgs,
        bytes32 salt
    ) external returns (address);

    function computeAddress(
        bytes memory bytecode,
        bytes memory constructorArgs,
        bytes32 salt
    ) external view returns (address);
}
