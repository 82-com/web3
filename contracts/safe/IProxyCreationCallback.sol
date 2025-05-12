// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.22;
import {SafeProxyV2} from "./SafeProxy.sol";

/**
 * @title IProxyCreationCallback
 * @dev An interface for a contract that implements a callback function to be executed after the creation of a proxy instance.
 */
interface IProxyCreationCallback {
    /**
     * @dev Function to be called after the creation of a SafeProxy instance.
     * @param proxy The newly created SafeProxy instance.
     * @param _singleton The address of the singleton contract used to create the proxy.
     * @param initializer The initializer function call data.
     * @param saltNonce The nonce used to generate the salt for the proxy deployment.
     */
    function proxyCreated(SafeProxyV2 proxy, address _singleton, bytes calldata initializer, uint256 saltNonce) external;
}