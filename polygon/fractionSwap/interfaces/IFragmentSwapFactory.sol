// SPDX-License-Identifier: GNU GPLv3

pragma solidity ^0.8.22;

interface IFragmentSwapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function setting() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function initCodeHash() external view returns (bytes32);

    function pairsExists(address pair) external view returns (bool);

    function createPair(address tokenA, address tokenB) external returns (address pair);
}
