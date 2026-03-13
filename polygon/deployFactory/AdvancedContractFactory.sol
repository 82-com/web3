// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title Advanced Contract Factory
/// @notice A factory contract for deploying new contracts using CREATE2 opcode
contract AdvancedContractFactory {
    /// @notice Emitted when a new contract is created
    /// @param contractAddress The address of the newly created contract
    /// @param salt The salt used for contract creation
    event ContractCreated(address contractAddress, bytes32 salt);

    /// @notice Error thrown when contract creation fails
    error ContractCreationFailed();

    /// @notice Create a new contract using CREATE2 opcode
    /// @param bytecode The bytecode of the contract to be deployed
    /// @param constructorArgs The constructor arguments for the contract
    /// @param salt The salt used to determine the contract address
    /// @return The address of the newly created contract
    function createContractWithSalt(
        bytes memory bytecode,
        bytes memory constructorArgs,
        bytes32 salt
    ) external returns (address) {
        address newContract;
        bytes memory creationCode = abi.encodePacked(bytecode, constructorArgs);

        assembly {
            newContract := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }

        if (newContract == address(0)) revert ContractCreationFailed();
        emit ContractCreated(newContract, salt);
        return newContract;
    }

    /// @notice Calculate the address of a contract that would be created with CREATE2
    /// @param bytecode The bytecode of the contract
    /// @param constructorArgs The constructor arguments for the contract
    /// @param salt The salt used to determine the contract address
    /// @return The computed address of the contract
    function computeAddress(
        bytes memory bytecode,
        bytes memory constructorArgs,
        bytes32 salt
    ) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(abi.encodePacked(bytecode, constructorArgs)))
        );
        return address(uint160(uint256(hash)));
    }
}
