// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IWrappedTokenFactory} from "./interfaces/IWrappedTokenFactory.sol";

contract WrappedTokenProxy is ERC1967Proxy {
    address public factory;

    constructor(
        address _logic,
        address _factory,
        uint8 _tokenDecimals,
        string memory _tokenName,
        string memory _tokenSymbol
    )
        ERC1967Proxy(
            _logic,
            abi.encodeWithSignature(
                "initialize(address,uint8,string,string)",
                _factory,
                _tokenDecimals,
                _tokenName,
                _tokenSymbol
            )
        )
    {
        factory = _factory;
    }

    /// @notice Gets the current implementation address from Setting Manager
    /// @dev Overrides ERC1967Proxy's implementation getter to provide dynamic logic contract address
    /// @return Address of the current logic contract
    function _implementation() internal view virtual override returns (address) {
        return IWrappedTokenFactory(factory).getLogic();
    }

    /// @notice Allows the contract to receive Ether
    /// @dev Required for the proxy to receive ETH transfers
    receive() external payable {}
}
