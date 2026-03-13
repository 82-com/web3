// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IProxyFactory {
    function createProxyWithSalt(
        address _owner,
        address[] memory _signers,
        uint256 _threshold,
        bytes32 salt
    ) external returns (address);

    function predictProxyAddressWithSalt(
        address _owner,
        address[] memory _signers,
        uint256 _threshold,
        bytes32 salt
    ) external view returns (address);

    event ProxyCreated(
        address indexed proxy,
        address logic,
        address owner,
        address[] signers,
        uint256 threshold,
        bytes32 salt
    );
}
