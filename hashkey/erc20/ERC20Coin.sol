// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Coin is ERC20, ERC20Permit {

    uint8 private immutable _decimals;

    uint256 private immutable _claimAmount;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) ERC20Permit(name_) {
        _decimals = decimals_;
        _claimAmount = 1e9 * 10 ** _decimals;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address[] calldata toList_) external {
        uint256 length = toList_.length;
        for (uint8 i_ = 0; i_ < length;) {
            _mint(toList_[i_], _claimAmount);
            unchecked{++i_;}
        }
    }

    function claim() external {
        _mint(msg.sender, _claimAmount);
    }
    

}
