// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IWrappedTokenFactory {
    function getLogic() external view returns (address);
}
