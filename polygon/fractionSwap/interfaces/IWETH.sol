// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.22;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}
