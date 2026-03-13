// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title ERC721Receiver
 * @dev Implementation of the {IERC721Receiver} interface.
 * This contract demonstrates how to safely handle ERC721 token transfers.
 */
contract ERC721Receiver is IERC721Receiver {
    /**
     * @dev Implementation of the IERC721Receiver interface function.
     * This function is called when an ERC721 token is transferred to this contract.
     * @return bytes4 The function selector to confirm successful receipt of the token
     * Note: The parameters are not used in this implementation but are required by the interface
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        // Return the function selector to indicate successful token receipt
        return this.onERC721Received.selector;
    }
}
