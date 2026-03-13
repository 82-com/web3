// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @notice 常量定义库
library ConfigRoleManagerLib {
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    /**
     * @notice Role for managing fee configurations
     * @dev Granted to fee administrators
     */
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    /**
     * @notice Role for managing token whitelisting
     * @dev Granted to token administrators
     */
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");

    /**
     * @notice Role for managing multi-signature wallets
     * @dev Granted to safe administrators
     */
    bytes32 public constant SAFE_MANAGER_ROLE = keccak256("SAFE_MANAGER_ROLE");

    /**
     * @notice Role for managing withdrawal signers
     * @dev Granted to signer administrators
     */
    bytes32 public constant SIGNER_MANAGER_ROLE = keccak256("SIGNER_MANAGER_ROLE");

    /**
     * @notice Role for managing fractional ownership settings
     * @dev Granted to fraction administrators
     */
    bytes32 public constant FRACTION_MANAGER_ROLE = keccak256("FRACTION_MANAGER_ROLE");

    function isAdminRole(address account, address targetContract) internal view returns (bool) {
        IAccessControl accessControl = IAccessControl(targetContract);
        return accessControl.hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function isFeeManagerRole(address account, address targetContract) internal view returns (bool) {
        IAccessControl accessControl = IAccessControl(targetContract);
        return accessControl.hasRole(FEE_MANAGER_ROLE, account);
    }

    function isTokenManagerRole(address account, address targetContract) internal view returns (bool) {
        IAccessControl accessControl = IAccessControl(targetContract);
        return accessControl.hasRole(TOKEN_MANAGER_ROLE, account);
    }

    function isSafeManagerRole(address account, address targetContract) internal view returns (bool) {
        IAccessControl accessControl = IAccessControl(targetContract);
        return accessControl.hasRole(SAFE_MANAGER_ROLE, account);
    }

    function isSignerManagerRole(address account, address targetContract) internal view returns (bool) {
        IAccessControl accessControl = IAccessControl(targetContract);
        return accessControl.hasRole(SIGNER_MANAGER_ROLE, account);
    }

    function isFractionManagerRole(address account, address targetContract) internal view returns (bool) {
        IAccessControl accessControl = IAccessControl(targetContract);
        return accessControl.hasRole(FRACTION_MANAGER_ROLE, account);
    }
}
