// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITransferAgent {
    function transferERC20(address _currency, address _from, address _to, uint256 _amount) external;
    function transferERC721(address _nftAddress, uint256 _nftTokenId, address _from, address _to) external;
}
