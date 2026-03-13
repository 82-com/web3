// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IEntryPoint {
    /**
     * @dev User operation structure
     */
    struct SimpleUserOperation {
        uint256 opId; // operation id
        address proxy; // Target proxy address
        bytes callData; // Calldata for the proxy
    }

    /**
     * @notice Handle multiple user operations
     * @param ops Array of user operations to execute
     */
    function handleOps(SimpleUserOperation[] calldata ops) external;

    /**
     * @notice Handle multiple user operations atomically
     * @param ops Array of user operations to execute
     */
    function handleOpsAtomic(SimpleUserOperation[] calldata ops) external;

    /**
     * @dev Error message for when a user operation fails
     */
    error UserOpFailed(uint256 opIndex, uint256 opId);

    /**
     * @dev Error message for when a batch of user operations is incomplete
     */
    event BatchIncomplete(uint256 opIndex, uint256 opId);

    /**
     * @dev Emitted when a user operation is successfully executed
     */
    event UserOperationSuccess(uint256 opId, address proxy, uint256 gasUsed);

    /**
     * @dev Emitted when a user operation fails
     */
    event UserOperationFailed(uint256 opId, address proxy, uint256 gasUsed, string reason);
}
