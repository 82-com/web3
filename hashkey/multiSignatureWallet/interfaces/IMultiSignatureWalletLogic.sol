// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMultiSignatureWalletLogic {
    function getInitialConfiguration() external view returns (address, address, address);

    function isNonceUsed(uint256 parallelNonce) external view returns (bool);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 parallelNonce
    ) external view returns (bytes32);

    function getModuleHash(address module, bytes calldata data, uint256 parallelNonce) external view returns (bytes32);

    function executeTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 parallelNonce,
        bytes[] calldata signatures,
        uint256 deadline
    ) external payable;

    function executeModuleTransaction(
        address module,
        bytes calldata data,
        uint256 parallelNonce,
        bytes[] calldata signatures,
        uint256 deadline
    ) external;

    function syncLogic() external;

    function addSigner(address _signer) external;

    function removeSigner(address _signer) external;

    function setThreshold(uint256 _threshold) external;
}
