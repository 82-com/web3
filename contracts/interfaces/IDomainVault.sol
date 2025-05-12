//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IDomainVault {

    function afterTokenTransferForDomainFraction(address from, address to, uint256 amount) external;
}
