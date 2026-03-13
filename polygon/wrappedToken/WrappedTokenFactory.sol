// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {WrappedTokenProxy} from "./WrappedTokenProxy.sol";

import {IWrappedTokenFactory} from "./interfaces/IWrappedTokenFactory.sol";

interface IERC20Simple {
    function mint(address to, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}

contract WrappedTokenFactory is IWrappedTokenFactory, AccessControlEnumerable {
    address logicAddress;
    mapping(address => address) public wrappedTokenProxy;
    // operator
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor(address _admin, address _logicAddress) {
        require(_logicAddress != address(0), "logic address cannot be zero");
        logicAddress = _logicAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
    }

    event createToken(address token, address wrappedTokenProxy);

    function getLogic() public view virtual returns (address) {
        return logicAddress;
    }

    function setLogic(address _logicAddress) external virtual onlyRole(OPERATOR_ROLE) {
        logicAddress = _logicAddress;
    }

    function mint(address token, address to, uint256 amount) public onlyRole(OPERATOR_ROLE) {
        IERC20Simple(token).mint(to, amount);
    }

    function burn(address token, address account, uint256 amount) public onlyRole(OPERATOR_ROLE) {
        IERC20Simple(token).burn(account, amount);
    }

    function mintByTokenAddress(address token, address to, uint256 amount) public onlyRole(OPERATOR_ROLE) {
        require(wrappedTokenProxy[token] != address(0), "WrappedToken: WRAPPED_TOKEN_NOT_CREATED");
        IERC20Simple(wrappedTokenProxy[token]).mint(to, amount);
    }

    function burnByTokenAddress(address token, address account, uint256 amount) public onlyRole(OPERATOR_ROLE) {
        require(wrappedTokenProxy[token] != address(0), "WrappedToken: WRAPPED_TOKEN_NOT_CREATED");
        IERC20Simple(wrappedTokenProxy[token]).burn(account, amount);
    }

    function createTokenByTokenAddress(
        address _token,
        uint8 _tokenDecimals,
        string calldata _tokenName,
        string calldata _tokenSymbol
    ) external onlyRole(OPERATOR_ROLE) returns (address newToken) {
        require(wrappedTokenProxy[_token] == address(0), "WrappedToken: WRAPPED_TOKEN_ALREADY_CREATED");

        bytes memory proxyBytecode = type(WrappedTokenProxy).creationCode;
        bytes memory initData = abi.encode(getLogic(), address(this), _tokenDecimals, _tokenName, _tokenSymbol);
        bytes memory creationCode = abi.encodePacked(proxyBytecode, initData);
        bytes32 salt = keccak256(abi.encodePacked(_token));
        assembly {
            newToken := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        require(newToken != address(0), "WrappedToken: CREATE2_FAILED");
        wrappedTokenProxy[_token] = newToken;

        emit createToken(_token, newToken);
    }
}
