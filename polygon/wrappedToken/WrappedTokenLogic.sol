// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Importing necessary OpenZeppelin upgradeable contracts
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract WrappedTokenLogic is ERC20Upgradeable {
    struct WrappedTokenStorage {
        address factory;
        uint8 decimals;
    }

    // keccak256("wrapped.token.logic")
    bytes32 private constant WrappedTokenStorageLocation =
        0x76c4633a7a1af57ce17697ea481223c3ab39e98830a2ac298c17aa2a44a4b45a;

    function _getWrappedTokenStorage() private pure returns (WrappedTokenStorage storage $) {
        assembly {
            $.slot := WrappedTokenStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _factory,
        uint8 _tokenDecimals,
        string calldata _tokenName,
        string calldata _tokenSymbol
    ) public initializer {
        __ERC20_init(_tokenName, _tokenSymbol);

        WrappedTokenStorage storage $ = _getWrappedTokenStorage();
        $.factory = _factory;
        $.decimals = _tokenDecimals;
    }

    modifier onlyFactory() {
        require(msg.sender == _getWrappedTokenStorage().factory, "Only factory can call this function");
        _;
    }

    function decimals() public view override returns (uint8) {
        return _getWrappedTokenStorage().decimals;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
    }

    function mint(address to, uint256 amount) public onlyFactory {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) public onlyFactory {
        _burn(account, amount);
    }
}
