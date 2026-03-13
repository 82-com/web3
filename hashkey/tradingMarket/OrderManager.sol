// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import {MultiTokenManager} from "./MultiTokenManager.sol";

/**
 * @title OrderManager
 * @dev Manages buy/sell orders for NFTs with collateral handling
 */
contract OrderManager is MultiTokenManager {
    // Struct representing a maker order
    struct MakerOrder {
        address currency; // Currency address
        uint256 price; // Order price
        uint128 endTime; // Order expiration timestamp
    }

    // Mapping of order hash to maker order details
    mapping(bytes32 => MakerOrder) public makerOrderMapping_discard;

    uint256[9] private __gap;
}
