// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.22;
import {SafeProxyV2} from "./SafeProxy.sol";
import {IProxyCreationCallback} from "./IProxyCreationCallback.sol";
import {SafeV2} from "./Safe.sol";
import {ISettingManager} from "../interfaces/ISettingManager.sol";
import {AdvancedContractFactory} from "../deployFactory/AdvancedContractFactory.sol";

/**
 * @title Proxy Factory - Allows to create a new proxy contract and execute a message call to the new proxy within one transaction.
 * @author Stefan George - @Georgi87
 */
contract SafeProxyFactoryV2 {
    event ProxyCreation(SafeProxyV2 indexed proxy, address singleton);
    address public _singletonFactory;

    constructor(address singletonFactory) {
        _singletonFactory = singletonFactory;
    }

    /// @dev Allows to retrieve the creation code used for the Proxy deployment. With this it is easily possible to calculate predicted address.
    function proxyCreationCode() public pure returns (bytes memory) {
        return type(SafeProxyV2).creationCode;
    }

    /**
     * @notice Deploys a new proxy with `_singleton` singleton and `saltNonce` salt. Optionally executes an initializer call to a new proxy.
     * @param _singleton Address of singleton contract. Must be deployed at the time of execution.
     * @param initializer Payload for a message call to be sent to a new proxy contract.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     */
    function createProxyWithNonce(
        address _singleton, 
        bytes memory initializer, 
        uint256 saltNonce
    ) public returns (SafeProxyV2 proxy) {
        require(isContract(_singleton), "Singleton contract not deployed");
        
        // Use generic factory contract for deployment
        AdvancedContractFactory factory = AdvancedContractFactory(_singletonFactory);
        address proxyAddress = factory.createContractWithSalt(
            type(SafeProxyV2).creationCode,
            "", // No parameters needed
            bytes32(saltNonce)
        );
        
        require(proxyAddress != address(0), "Deployment failed");
        proxy = SafeProxyV2(payable(proxyAddress));
        
        // Initialize proxy contract
        proxy.init(_singleton);

        if (initializer.length > 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                    let size := returndatasize()
                    let returnData := mload(0x40)
                    mstore(0x40, add(returnData, add(0x20, size)))
                    mstore(returnData, size)
                    returndatacopy(add(returnData, 0x20), 0, size)
                    revert(add(returnData, 0x20), size)
                }
            }
        }

        // Add Safe proxy to whitelist after initialization
        SafeV2 safe = SafeV2(payable(proxy));
        address settingManagerAddress = address(safe.settingManager());
        if (settingManagerAddress != address(0)) {
            // Call addSafeProxy to add Safe to whitelist
            ISettingManager(settingManagerAddress).addSafeProxy(proxyAddress);
        }
        emit ProxyCreation(proxy, _singleton);
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @dev This function will return false if invoked during the constructor of a contract,
     *      as the code is not actually created until after the constructor finishes.
     * @param account The address being queried
     * @return True if `account` is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
