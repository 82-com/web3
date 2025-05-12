// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract AdvancedContractFactory {
    event ContractCreated(address contractAddress, bytes32 salt);

    error ContractCreationFailed();

    // Create contract using create2
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

    // Calculate create2 contract address
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
