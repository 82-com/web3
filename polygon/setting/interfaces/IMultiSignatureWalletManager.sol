// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMultiSignatureWalletManager {
    event WalletLogicUpdated(address _newLogic);
    event MultiSignatureWalletAdd(address _walletAddress);
    event MultiSignatureWalletRemoved(address _walletAddress);
    event MinterAdded(address _minter);
    event MinterRemoved(address _minter);

    function getWalletLogic() external view returns (address);

    function isMultiSignatureWallet(address _walletAddress) external view returns (bool);

    function isSafeReceiver(address _address) external view returns (bool);

    function getMultiSignatureWalletSetLength() external view returns (uint256);

    function getMultiSignatureWalletSetPagination(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory);

    function setWalletLogic(address _newLogic) external;

    function addMultiSignatureWallet(address _walletAddress) external;

    function removeMultiSignatureWallet(address _walletAddress) external;

    function getWalletMinter() external view returns (address[] memory);

    function isWalletMinter(address _minter) external view returns (bool);

    function addWalletMinter(address _minter) external;

    function removeWalletMinter(address _minter) external;
}
