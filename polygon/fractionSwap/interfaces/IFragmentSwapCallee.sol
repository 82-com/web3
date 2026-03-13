// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.22;

interface IFragmentSwapCallee {
    function fragmentSwapCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
