// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.22;
import {SafeV2} from "./Safe.sol";
import {ISettingManager} from "../interfaces/ISettingManager.sol";
import {ITransferAgent} from "../interfaces/ITransferAgent.sol";

/**
 * @title IProxy - Helper interface to access the singleton address of the Proxy on-chain.
 * @author Richard Meissner - @rmeissner
 */
interface IProxy {
    function masterCopy() external view returns (address);
}

// Add ERC721 receiver interface
interface IERC721Receiver {
    /**
     * @dev Called when an ERC721 token is transferred via safeTransferFrom or safeMint
     * @param operator The address which called the transfer or mint function
     * @param from The address which previously owned the token
     * @param tokenId The ID of the transferred token
     * @param data Additional data
     * @return The standard selector to confirm the contract can receive ERC721
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title SafeProxy - Generic proxy contract allows to execute all transactions applying the code of a master contract.
 * @author Stefan George - <stefan@gnosis.io>
 * @author Richard Meissner - <richard@gnosis.io>
 */
contract SafeProxyV2 is IERC721Receiver {
    // Singleton always needs to be first declared variable, to ensure that it is at the same location in the contracts to which calls are delegated.
    // To reduce deployment costs this variable is internal and needs to be retrieved via `getStorageAt`
    address payable internal singleton;

    /**
     * @notice Initialize the proxy contract
     * @param _singleton Singleton address
     */
    function init(address _singleton) external {
        require(singleton == address(0), "Already initialized");
        require(_singleton != address(0), "Invalid singleton address provided");
        singleton = payable(_singleton);
    }

    /**
     * @notice Implements ERC721 receiver interface, allowing the contract to receive ERC721 tokens
     * @dev Returns standard selector to confirm the contract can receive ERC721
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}

    /// @dev Fallback function forwards all transactions and returns all received return data.
    fallback() external payable {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let _singleton := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(calldataload(0), 0xa619486e00000000000000000000000000000000000000000000000000000000) {
                mstore(0, _singleton)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
