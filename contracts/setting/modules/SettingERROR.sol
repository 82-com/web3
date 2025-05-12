// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

abstract contract SettingERROR {
    // ************************************
    // *           Errors                 *
    // ************************************
    error Unauthorized(address addr);

    error AlreadyWhitelisted(address addr);
    error NotWhitelisted(address addr);

    error InvalidToken(address token);

    error InvalidFeeRate(uint64 feeRate, uint64 denominator);

    error ZeroAddress();

    // ************************************
    // *           Modifiers              *
    // ************************************

    /**
     * @dev Validates address is not zero
     * @param addr Address to validate
     */
    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }
}
