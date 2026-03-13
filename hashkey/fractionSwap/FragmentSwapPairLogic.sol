// SPDX-License-Identifier: GNU GPLv3

/// @title FragmentSwap Pair Logic Contract
/// @notice Core logic implementation for FragmentSwap token pairs
/// @dev Implements swap, liquidity provision and price oracle functionality
/// @dev Inherits from ERC20PermitUpgradeable for LP token functionality
/// @dev Uses ReentrancyGuard for protection against reentrancy attacks

import {UQ112x112} from "./libraries/UQ112x112.sol";
import {Math} from "./libraries/Math.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUpgradeable} from "./FractionSwapERC20Permit.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IFragmentSwapFactory} from "./interfaces/IFragmentSwapFactory.sol";
import {IFragmentSwapPair} from "./interfaces/IFragmentSwapPair.sol";
import {IFragmentSwapCallee} from "./interfaces/IFragmentSwapCallee.sol";
import {IFeesManager} from "../setting/interfaces/IFeesManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";

pragma solidity ^0.8.22;

/// @title FragmentSwap Pair Logic
/// @notice Core implementation contract for token pair exchanges
/// @dev Manages liquidity, swaps, and price oracles for token pairs
/// @dev Uses upgradeable pattern with storage in separate struct
contract FragmentSwapPairLogic is IFragmentSwapPair, ERC20PermitUpgradeable, ReentrancyGuardUpgradeable {
    using UQ112x112 for uint224;

    /// @notice Struct for local swap variables to reduce stack depth
    /// @dev Used internally in swap function
    struct SwapLocalVars {
        uint112 reserve0; // Reserve of token0
        uint112 reserve1; // Reserve of token1
        uint256 balance0; // Current balance of token0
        uint256 balance1; // Current balance of token1
        uint256 amount0In; // Input amount of token0
        uint256 amount1In; // Input amount of token1
    }

    /// @notice Minimum liquidity amount to lock
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    /// @dev ERC20 transfer selector
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    /// @dev Storage slot for pair data
    bytes32 private constant SwapPairStorageLocal = keccak256("fragment.swap.pair.logic");

    /// @notice Struct containing all pair storage variables
    /// @dev Uses dedicated storage slot to avoid collision
    struct SwapPairStorage {
        address factory; // Factory contract address
        address token0; // First token in pair
        address token1; // Second token in pair
        uint112 reserve0; // Reserve of token0
        uint112 reserve1; // Reserve of token1
        uint32 blockTimestampLast; // Last block timestamp
        uint224 price0CumulativeLast; // Cumulative price for token0
        uint224 price1CumulativeLast; // Cumulative price for token1
        uint256 kLast; // Last invariant (reserve0 * reserve1)
        address settingManager; // Address of setting manager contract
        address transferAgent;
    }

    /// @notice Gets the storage struct from predefined slot
    /// @return sps Reference to the storage struct
    function _getSwapPairStorage() private pure returns (SwapPairStorage storage sps) {
        bytes32 slot = SwapPairStorageLocal;
        assembly {
            sps.slot := slot
        }
    }

    /// @notice Gets the factory address
    /// @return Factory contract address
    function factory() external view override returns (address) {
        return _getSwapPairStorage().factory;
    }

    /// @notice Gets token0 address
    /// @return First token in pair
    function token0() external view override returns (address) {
        return _getSwapPairStorage().token0;
    }

    /// @notice Gets token1 address
    /// @return Second token in pair
    function token1() external view override returns (address) {
        return _getSwapPairStorage().token1;
    }

    /// @notice Gets last cumulative price for token0
    /// @return Cumulative price value
    function price0CumulativeLast() external view override returns (uint224) {
        return _getSwapPairStorage().price0CumulativeLast;
    }

    /// @notice Gets last cumulative price for token1
    /// @return Cumulative price value
    function price1CumulativeLast() external view override returns (uint224) {
        return _getSwapPairStorage().price1CumulativeLast;
    }

    /// @notice Gets last invariant value (k = reserve0 * reserve1)
    /// @return Last k value
    function kLast() external view override returns (uint256) {
        return _getSwapPairStorage().kLast;
    }

    /// @notice Gets current reserves and last block timestamp
    /// @return reserve0 Reserve of token0
    /// @return reserve1 Reserve of token1
    /// @return blockTimestampLast Last block timestamp
    function getReserves() public view returns (uint256, uint256, uint32) {
        SwapPairStorage storage sps = _getSwapPairStorage();
        return (uint256(sps.reserve0), uint256(sps.reserve1), sps.blockTimestampLast);
    }

    /// @dev Disables initializers in constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the pair contract
    /// @param _token0 First token address
    /// @param _token1 Second token address
    /// @param _settingManager Setting manager contract address
    /// @param _transferAgent Transfer agent contract address
    /// @dev Called once when pair is created
    function initialize(
        address _token0,
        address _token1,
        address _settingManager,
        address _transferAgent
    ) external initializer {
        __ERC20_init("FragmentSwapLP", "FS-LP");
        __ERC20Permit_init("FragmentSwapLP");

        SwapPairStorage storage sps = _getSwapPairStorage();
        sps.factory = msg.sender;
        sps.token0 = _token0;
        sps.token1 = _token1;
        sps.settingManager = _settingManager;
        sps.transferAgent = _transferAgent;
    }

    /// @notice Updates reserves and accumulates price
    /// @param balance0 New balance of token0
    /// @param balance1 New balance of token1
    /// @param _reserve0 Previous reserve of token0
    /// @param _reserve1 Previous reserve of token1
    /// @dev Maintains price oracle and updates reserves
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "FragmentSwap: OVERFLOW");
        SwapPairStorage storage sps = _getSwapPairStorage();
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - sps.blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            sps.price0CumulativeLast += uint224(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            sps.price1CumulativeLast += uint224(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        sps.reserve0 = uint112(balance0);
        sps.reserve1 = uint112(balance1);
        sps.blockTimestampLast = blockTimestamp;
        sps.kLast = uint256(sps.reserve0) * uint256(sps.reserve1);
        emit Sync(sps.reserve0, sps.reserve1);
    }

    /// @notice Performs token swap
    /// @param amount0Out Amount of token0 to send out
    /// @param amount1Out Amount of token1 to send out
    /// @param to Recipient address
    /// @param data Additional data for flash swaps
    /// @dev Implements swap logic with fee calculation
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "FragmentSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        SwapPairStorage storage sps = _getSwapPairStorage();
        IFeesManager.SwapFees memory swapFees = IFeesManager(sps.settingManager).getSwapFeesStruct();

        // Use struct to reduce stack depth
        SwapLocalVars memory vars;
        vars.reserve0 = sps.reserve0;
        vars.reserve1 = sps.reserve1;
        require(amount0Out < vars.reserve0 && amount1Out < vars.reserve1, "FragmentSwap: INSUFFICIENT_LIQUIDITY");

        // Transfer output tokens
        {
            address _token0 = sps.token0;
            address _token1 = sps.token1;
            require(to != _token0 && to != _token1, "FragmentSwap: INVALID_TO");

            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);

            if (data.length > 0) IFragmentSwapCallee(to).fragmentSwapCall(msg.sender, amount0Out, amount1Out, data);

            vars.balance0 = IERC20(_token0).balanceOf(address(this));
            vars.balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // Calculate input amounts
        vars.amount0In = vars.balance0 > (vars.reserve0 - amount0Out)
            ? vars.balance0 - (vars.reserve0 - amount0Out)
            : 0;
        vars.amount1In = vars.balance1 > (vars.reserve1 - amount1Out)
            ? vars.balance1 - (vars.reserve1 - amount1Out)
            : 0;
        require(vars.amount0In > 0 || vars.amount1In > 0, "FragmentSwap: INSUFFICIENT_INPUT_AMOUNT");

        // Apply fees
        {
            require(swapFees.swapFeeReceiver != address(0), "FragmentSwap: INVALID_FEE_RECEIVER");
            if (vars.amount0In > 0) {
                uint256 totalFee = (vars.amount0In * (swapFees.swapFee + swapFees.swapLpFee)) / swapFees.denominator;
                uint256 feeAmount = (vars.amount0In * swapFees.swapFee) / swapFees.denominator;
                _safeTransfer(sps.token0, swapFees.swapFeeReceiver, feeAmount);
                emit ProtocolFees(swapFees.swapFeeReceiver, sps.token0, feeAmount);
                vars.amount0In -= totalFee;
                vars.balance0 -= feeAmount;
            } else {
                uint256 totalFee = (vars.amount1In * (swapFees.swapFee + swapFees.swapLpFee)) / swapFees.denominator;
                uint256 feeAmount = (vars.amount1In * swapFees.swapFee) / swapFees.denominator;
                _safeTransfer(sps.token1, swapFees.swapFeeReceiver, feeAmount);
                emit ProtocolFees(swapFees.swapFeeReceiver, sps.token1, feeAmount);
                vars.amount1In -= totalFee;
                vars.balance1 -= feeAmount;
            }
            require(vars.balance0 * vars.balance1 >= vars.reserve0 * vars.reserve1, "FragmentSwap: K");
        }

        _update(vars.balance0, vars.balance1, vars.reserve0, vars.reserve1);
        emit Swap(msg.sender, vars.amount0In, vars.amount1In, amount0Out, amount1Out, to);
    }

    /// @notice Mints liquidity tokens
    /// @param to Recipient address
    /// @return liquidity Amount of LP tokens minted
    /// @dev Calculates liquidity based on deposited amounts
    function mint(address to) external nonReentrant returns (uint liquidity) {
        SwapPairStorage storage sps = _getSwapPairStorage();
        uint256 balance0 = uint256(IERC20(sps.token0).balanceOf(address(this)));
        uint256 balance1 = uint256(IERC20(sps.token1).balanceOf(address(this)));
        uint256 amount0 = balance0 - sps.reserve0;
        uint256 amount1 = balance1 - sps.reserve1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - (MINIMUM_LIQUIDITY);
            _mintPond(MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * (_totalSupply)) / sps.reserve0, (amount1 * _totalSupply) / sps.reserve1);
        }
        require(liquidity > 0, "FragmentSwap: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, sps.reserve0, sps.reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice Burns liquidity tokens
    /// @param to Recipient address
    /// @return amount0 Amount of token0 returned
    /// @return amount1 Amount of token1 returned
    /// @dev Returns proportional amounts of both tokens
    function burn(address to) external nonReentrant returns (uint amount0, uint amount1) {
        SwapPairStorage storage sps = _getSwapPairStorage();
        address _token0 = sps.token0;
        address _token1 = sps.token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        uint _totalSupply = totalSupply();
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 || amount1 > 0, "FragmentSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, sps.reserve0, sps.reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice Skims excess tokens to specified address
    /// @param to Recipient address
    /// @dev Transfers amounts above reserves to given address
    function skim(address to) external nonReentrant {
        SwapPairStorage storage sps = _getSwapPairStorage();
        address _token0 = sps.token0;
        address _token1 = sps.token1;
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - (sps.reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - (sps.reserve1));
    }

    /// @notice Syncs reserves with current balances
    /// @dev Forces reserves to match actual token balances
    function sync() external nonReentrant {
        SwapPairStorage storage sps = _getSwapPairStorage();
        _update(
            IERC20(sps.token0).balanceOf(address(this)),
            IERC20(sps.token1).balanceOf(address(this)),
            sps.reserve0,
            sps.reserve1
        );
    }

    /// @notice Safely transfers tokens with receiver validation
    /// @param token Token address
    /// @param to Recipient address
    /// @param value Amount to transfer
    /// @dev Checks receiver against safe receiver list
    function _safeTransfer(address token, address to, uint value) private {
        SwapPairStorage storage sps = _getSwapPairStorage();
        require(
            IMultiSignatureWalletManager(sps.settingManager).isSafeReceiver(to) ||
                IFragmentSwapFactory(sps.factory).pairsExists(to),
            "FragmentSwap: NOT_SAFE_TO_TRANSFER"
        );
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "FragmentSwap: TRANSFER_FAILED");
    }

    /// @notice Gets nonce for permit functionality
    /// @param owner Token owner address
    /// @return Current nonce
    function nonces(
        address owner
    ) public view virtual override(ERC20PermitUpgradeable, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    /// @notice Gets token decimals
    /// @return Fixed value of 6
    function decimals() public pure virtual override returns (uint8) {
        return 6;
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal override {
        SwapPairStorage storage sps = _getSwapPairStorage();
        if (spender == sps.transferAgent) return;
        super._spendAllowance(owner, spender, value);
    }
}
