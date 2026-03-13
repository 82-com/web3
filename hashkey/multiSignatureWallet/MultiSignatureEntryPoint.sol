// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "./interfaces/IEntryPoint.sol";

/**
 * @title MultiSignature Entry Point Contract
 * @notice Main entry point for handling multi-signature wallet operations with batch processing
 * @dev Implements the entry point pattern for multi-signature wallet operations with gas optimization
 * and error handling. Uses try/catch to prevent single operation failure from affecting entire batch.
 * This is part of the proxy wallet system, providing a unified entry point for batch execution of proxy wallets.
 * Validation is performed within the proxy wallets themselves.
 */
contract MultiSignatureEntryPoint is IEntryPoint {
    /// @notice Error code constant for inner out of gas condition
    /// @dev keccak256("INNER_OUT_OF_GAS")
    bytes32 private constant INNER_OUT_OF_GAS = 0xbc1f0db6aa8c8187aa18e72b51335cb5f84560c664dd76febd4bf856aed02eca;

    /// @notice Minimum gas reserve required for cleanup operations
    /// @dev Ensures sufficient gas remains for cleanup after execution
    uint256 immutable minGasReserve = 30000;

    /**
     * @notice Handle multiple user operations in batch
     * @dev Main entry point for processing user operations - single failure doesn't affect entire batch
     * @param ops Array of SimpleUserOperation to be processed
     */
    function handleOps(SimpleUserOperation[] calldata ops) public {
        // Iterate through the operations list
        for (uint i = 0; i < ops.length; i++) {
            if (!_executeUserOp(ops[i])) {
                // Emit event when gas is insufficient, not all operations processed
                emit BatchIncomplete(i, ops[i].opId);
                break;
            }
        }
    }

    /**
     * @notice Handle multiple user operations atomically
     */
    function handleOpsAtomic(SimpleUserOperation[] calldata ops) public {
        for (uint i = 0; i < ops.length; i++) {
            if (!_executeUserOp(ops[i])) {
                revert UserOpFailed(i, ops[i].opId);
            }
        }
    }

    /**
     * @notice Validate and execute a single user operation
     * @dev Uses try/catch to prevent single operation failure from affecting the batch
     * @param userOp The user operation to execute
     * @return success Returns true if operation completed successfully or failed with non-gas error,
     *         false if operation failed due to insufficient gas
     */
    function _executeUserOp(SimpleUserOperation calldata userOp) internal returns (bool) {
        uint256 initialGas = gasleft();
        bool success = false;
        bytes memory result;

        try this.innerHandleOp(userOp) returns (bool _success, bytes memory _result) {
            success = _success;
            result = _result;
        } catch (bytes memory errorData) {
            // Extract revert code
            bytes32 revertCode;
            if (errorData.length >= 32) {
                assembly {
                    revertCode := mload(add(errorData, 32))
                }
            } else {
                revertCode = keccak256(errorData);
            }

            // Handle specific error conditions
            if (revertCode == INNER_OUT_OF_GAS) {
                // Insufficient gas - emit failure event and stop processing further operations
                emit UserOperationFailed(userOp.opId, userOp.proxy, initialGas - gasleft(), "out of gas");
                return false;
            }
            // Other error conditions
            string memory reason = _getRevertReason(errorData);
            emit UserOperationFailed(userOp.opId, userOp.proxy, initialGas - gasleft(), reason);
            return true;
        }

        // Record operation result
        uint256 gasUsed = initialGas - gasleft();
        if (success) {
            emit UserOperationSuccess(userOp.opId, userOp.proxy, gasUsed);
        } else {
            emit UserOperationFailed(userOp.opId, userOp.proxy, gasUsed, _getRevertReason(result));
        }
        return true;
    }

    /**
     * @notice Internal operation handler - called externally to enable try/catch
     * @dev This function is called via external call to enable try/catch error handling
     * @param userOp The user operation to handle
     * @return success Boolean indicating if the operation succeeded
     * @return result Bytes containing the operation result or error data
     */
    function innerHandleOp(SimpleUserOperation calldata userOp) external returns (bool, bytes memory) {
        require(msg.sender == address(this), "EntryPoint: only self call");
        // Execute main call
        (bool success, bytes memory result) = _execute(userOp);
        // Check if gas is sufficient
        if (gasleft() < minGasReserve) {
            // Reserve small amount of gas for cleanup
            assembly {
                mstore(0, INNER_OUT_OF_GAS)
                revert(0, 32)
            }
        }

        return (success, result);
    }

    /**
     * @notice Execute the main call for user operation
     * @dev Performs the actual call to the proxy contract, returns result instead of reverting
     * @param userOp The user operation to execute
     * @return success Boolean indicating if the call succeeded
     * @return result Bytes containing the call result
     */
    function _execute(SimpleUserOperation calldata userOp) internal returns (bool success, bytes memory result) {
        // Execute the call to the proxy
        (success, result) = userOp.proxy.call{value: 0}(userOp.callData);
    }

    /**
     * @notice Extract error reason from revert data
     * @dev Parses revert data to extract human-readable error messages
     * @param revertData The revert data bytes to parse
     * @return reason String containing the extracted error reason
     */
    function _getRevertReason(bytes memory revertData) internal pure returns (string memory) {
        if (revertData.length == 0) {
            return "Unknown error";
        }
        // If revert data is encoded in Error(string) format
        if (revertData.length > 4 && bytes4(revertData) == 0x08c379a0) {
            assembly {
                revertData := add(revertData, 4)
            }
            return abi.decode(revertData, (string));
        }
        // Otherwise return generic error message
        return "Execution reverted";
    }
}
