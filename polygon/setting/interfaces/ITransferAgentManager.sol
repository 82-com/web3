// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITransferAgentManager {
    event TransferAgentExchangeAdd(address exchange);
    event TransferAgentExchangeRemoved(address exchange);

    function isTransferAgentExchange(address exchange) external view returns (bool);

    function getTransferAgentExchangeSet() external view returns (address[] memory);

    function addTransferAgentExchange(address exchange) external;

    function removeTransferAgentExchange(address exchange) external;
}
