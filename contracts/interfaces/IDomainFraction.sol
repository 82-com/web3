//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDomainFraction is IERC20 {

    function domainVault() external view returns (address);

    function originalTotalSupply() external view returns (uint256);

    function burnForDomainVault(uint256 amount) external;

}
