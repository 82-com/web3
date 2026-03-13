// SPDX-License-Identifier: GNU GPLv3

/// @title FractionSwap Router Contract
/// @notice Router for swapping and managing liquidity on FragmentSwap
/// @dev Implements IFragmentSwapRouter02 interface and handles all swap/liquidity operations

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {FragmentswapV2Library} from "./libraries/FragmentswapV2Library.sol";
import {FractionOrderBook} from "./FractionOrderBook.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";

import {IFragmentSwapFactory} from "./interfaces/IFragmentSwapFactory.sol";
import {IFragmentSwapPair} from "./interfaces/IFragmentSwapPair.sol";
import {IFragmentSwapRouter02} from "./interfaces/IFragmentSwapRouter02.sol";
import {ITransferAgent} from "../transfer/interfaces/ITransferAgent.sol";
import {IFeesManager} from "../setting/interfaces/IFeesManager.sol";

pragma solidity ^0.8.22;

/// @title FractionSwap Router
/// @notice Provides functions for swapping tokens and managing liquidity on FragmentSwap
/// @dev Handles all swap operations and liquidity management with safety checks
contract FractionSwapRouter is IFragmentSwapRouter02, FractionOrderBook {
    /// @notice Address of the FragmentSwap Factory contract
    address public immutable factory;

    /// @notice Address of the WETH contract
    address public immutable WETH;

    /// @notice Address of the Setting Manager contract for fee configuration
    address public immutable settingManager;

    /// @notice Address of the Transfer Agent contract for secure token transfers
    address public immutable transferAgent;

    /// @dev Hash of the pair contract creation code for address derivation
    bytes32 private _initCodeHash;

    /// @notice Modifier to ensure transaction is not expired
    /// @param deadline The timestamp after which the transaction is invalid
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "FragmentswapV2Router: EXPIRED");
        _;
    }

    /// @notice Constructs the FractionSwapRouter contract
    /// @param _factory Address of the FragmentSwap Factory
    /// @param _WETH Address of the WETH contract
    /// @param _settingManager Address of the Setting Manager contract
    /// @param _transferAgent Address of the Transfer Agent contract
    /// @dev Initializes the router with core contract addresses and gets initCodeHash
    constructor(
        address _factory,
        address _WETH,
        address _settingManager,
        address _transferAgent
    ) FractionOrderBook(_settingManager, _transferAgent) {
        factory = _factory;
        WETH = _WETH;
        settingManager = _settingManager;
        transferAgent = _transferAgent;
        _initCodeHash = IFragmentSwapFactory(factory).initCodeHash();
    }

    /// @notice Accepts ETH deposits only from WETH contract
    /// @dev This function allows the contract to receive ETH only from WETH withdrawals
    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    /// @notice Calculates the effective fee rate for swaps
    /// @dev Queries the setting manager for current fee structure
    /// @return feeRate The effective fee rate after deducting swap and LP fees
    /// @return denominator The fee denominator used for calculations
    function _getFeeRate() internal view returns (uint, uint) {
        IFeesManager.SwapFees memory swapFees = IFeesManager(settingManager).getSwapFeesStruct();
        uint feeRate = swapFees.denominator - swapFees.swapFee - swapFees.swapLpFee;
        return (feeRate, swapFees.denominator);
    }

    /// @notice Internal function to handle token transfers via Transfer Agent
    /// @dev Uses the Transfer Agent contract for secure token transfers
    /// @param _transferType The type of transfer (AddLiquidity, RemoveLiquidity, etc.)
    /// @param token The address of the token to transfer
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param value The amount of tokens to transfer
    function _transferFrom(
        ITransferAgent.ERC20TransferType _transferType,
        address token,
        address from,
        address to,
        uint value
    ) internal {
        try ITransferAgent(transferAgent).transferERC20(_transferType, token, from, to, value) {} catch {
            revert("TransferAgent: TRANSFER_FROM_FAILED");
        }
    }

    /// @notice Internal function to add liquidity between two tokens
    /// @dev Calculates optimal token amounts and creates pair if it doesn't exist
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @param amountADesired Desired amount of tokenA to add
    /// @param amountBDesired Desired amount of tokenB to add
    /// @param amountAMin Minimum amount of tokenA to add
    /// @param amountBMin Minimum amount of tokenB to add
    /// @return amountA Actual amount of tokenA added
    /// @return amountB Actual amount of tokenB added
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        IFragmentSwapFactory factoryContract = IFragmentSwapFactory(factory);
        if (factoryContract.getPair(tokenA, tokenB) == address(0)) {
            factoryContract.createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = FragmentswapV2Library.getReserves(factory, tokenA, tokenB, _initCodeHash);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = FragmentswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "FragmentswapV2Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = FragmentswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "FragmentswapV2Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /// @notice Adds liquidity for a token pair
    /// @dev External wrapper for _addLiquidity that handles token transfers
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @param amountADesired Desired amount of tokenA to add
    /// @param amountBDesired Desired amount of tokenB to add
    /// @param amountAMin Minimum amount of tokenA to add
    /// @param amountBMin Minimum amount of tokenB to add
    /// @param to Address to receive liquidity tokens
    /// @param deadline Deadline for the transaction
    /// @return amountA Actual amount of tokenA added
    /// @return amountB Actual amount of tokenB added
    /// @return liquidity Amount of liquidity tokens minted
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = FragmentswapV2Library.pairFor(factory, tokenA, tokenB, _initCodeHash);
        _transferFrom(ITransferAgent.ERC20TransferType.AddLiquidity, tokenA, msg.sender, pair, amountA);
        _transferFrom(ITransferAgent.ERC20TransferType.AddLiquidity, tokenB, msg.sender, pair, amountB);
        liquidity = IFragmentSwapPair(pair).mint(to);
    }

    /// @notice Adds liquidity with ETH
    /// @dev Adds liquidity for a token-ETH pair, handling ETH wrapping
    /// @param token Address of the token
    /// @param amountTokenDesired Desired amount of token to add
    /// @param amountTokenMin Minimum amount of token to add
    /// @param amountETHMin Minimum amount of ETH to add
    /// @param to Address to receive liquidity tokens
    /// @param deadline Deadline for the transaction
    /// @return amountToken Actual amount of token added
    /// @return amountETH Actual amount of ETH added
    /// @return liquidity Amount of liquidity tokens minted
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = FragmentswapV2Library.pairFor(factory, token, WETH, _initCodeHash);
        _transferFrom(ITransferAgent.ERC20TransferType.AddLiquidity, token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IFragmentSwapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    /// @notice Removes liquidity for a token pair
    /// @dev Burns LP tokens and returns underlying tokens to sender
    /// @param tokenA Address of first token in the pair
    /// @param tokenB Address of second token in the pair
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum amount of tokenA to receive
    /// @param amountBMin Minimum amount of tokenB to receive
    /// @param to Address to receive underlying tokens
    /// @param deadline Deadline for the transaction
    /// @return amountA Amount of tokenA received
    /// @return amountB Amount of tokenB received
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = FragmentswapV2Library.pairFor(factory, tokenA, tokenB, _initCodeHash);
        _transferFrom(ITransferAgent.ERC20TransferType.RemoveLiquidity, pair, msg.sender, pair, liquidity);
        (uint amount0, uint amount1) = IFragmentSwapPair(pair).burn(to);
        (address token0, ) = FragmentswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "FragmentswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "FragmentswapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    /// @notice Removes liquidity for a token-ETH pair
    /// @dev Burns LP tokens and returns token and ETH to sender
    /// @param token Address of the token in the pair
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountTokenMin Minimum amount of token to receive
    /// @param amountETHMin Minimum amount of ETH to receive
    /// @param to Address to receive underlying assets
    /// @param deadline Deadline for the transaction
    /// @return amountToken Amount of token received
    /// @return amountETH Amount of ETH received
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /// @notice Removes liquidity with permit signature for LP token approval
    /// @dev Allows removing liquidity without prior approval via EIP-712 permit
    /// @param tokenA Address of first token in the pair
    /// @param tokenB Address of second token in the pair
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum amount of tokenA to receive
    /// @param amountBMin Minimum amount of tokenB to receive
    /// @param to Address to receive underlying tokens
    /// @param deadline Deadline for the transaction
    /// @param approveMax Whether to approve the maximum amount or exact liquidity
    /// @param v The recovery byte of the signature
    /// @param r Half of the ECDSA signature pair
    /// @param s Half of the ECDSA signature pair
    /// @return amountA Amount of tokenA received
    /// @return amountB Amount of tokenB received
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = FragmentswapV2Library.pairFor(factory, tokenA, tokenB, _initCodeHash);
        uint value = approveMax ? type(uint256).max : liquidity;
        IFragmentSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /// @notice Removes liquidity for a token-ETH pair with permit signature
    /// @dev Allows removing liquidity without prior approval via EIP-712 permit
    /// @param token Address of the token in the pair
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountTokenMin Minimum amount of token to receive
    /// @param amountETHMin Minimum amount of ETH to receive
    /// @param to Address to receive underlying assets
    /// @param deadline Deadline for the transaction
    /// @param approveMax Whether to approve the maximum amount or exact liquidity
    /// @param v The recovery byte of the signature
    /// @param r Half of the ECDSA signature pair
    /// @param s Half of the ECDSA signature pair
    /// @return amountToken Amount of token received
    /// @return amountETH Amount of ETH received
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = FragmentswapV2Library.pairFor(factory, token, WETH, _initCodeHash);
        uint value = approveMax ? type(uint256).max : liquidity;
        IFragmentSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    /// @notice Removes liquidity for a token-ETH pair supporting fee-on-transfer tokens
    /// @dev Handles tokens that take a fee on transfer by checking final balance
    /// @param token Address of the token in the pair
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountTokenMin Minimum amount of token to receive (after fees)
    /// @param amountETHMin Minimum amount of ETH to receive
    /// @param to Address to receive underlying assets
    /// @param deadline Deadline for the transaction
    /// @return amountETH Amount of ETH received
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /// @notice Removes liquidity for a token-ETH pair with permit signature, supporting fee-on-transfer tokens
    /// @dev Combines permit signature with fee-on-transfer token support
    /// @param token Address of the token in the pair
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountTokenMin Minimum amount of token to receive (after fees)
    /// @param amountETHMin Minimum amount of ETH to receive
    /// @param to Address to receive underlying assets
    /// @param deadline Deadline for the transaction
    /// @param approveMax Whether to approve the maximum amount or exact liquidity
    /// @param v The recovery byte of the signature
    /// @param r Half of the ECDSA signature pair
    /// @param s Half of the ECDSA signature pair
    /// @return amountETH Amount of ETH received
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = FragmentswapV2Library.pairFor(factory, token, WETH, _initCodeHash);
        uint value = approveMax ? type(uint256).max : liquidity;
        IFragmentSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    /// @notice Internal function to execute swaps along the defined path
    /// @dev Performs a series of swaps through the path of token pairs
    /// @param amounts Array of input/output amounts for each swap in the path
    /// @param path Array of token addresses representing the swap path
    /// @param _to Address to receive the final output tokens
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FragmentswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2
                ? FragmentswapV2Library.pairFor(factory, output, path[i + 2], _initCodeHash)
                : _to;
            IFragmentSwapPair(FragmentswapV2Library.pairFor(factory, input, output, _initCodeHash)).swap(
                uint112(amount0Out),
                uint112(amount1Out),
                to,
                new bytes(0)
            );
        }
    }

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
    /// @dev Ensures minimum output amount is received and handles token transfer
    /// @param amountIn Exact amount of input tokens to send
    /// @param amountOutMin Minimum amount of output tokens to receive
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the output tokens
    /// @param deadline Deadline for the transaction
    /// @return amounts Array of input/output amounts for each swap in the path
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        (uint feeRate, uint denominator) = _getFeeRate();
        amounts = FragmentswapV2Library.getAmountsOut(factory, amountIn, path, feeRate, denominator, _initCodeHash);
        require(amounts[amounts.length - 1] >= amountOutMin, "FragmentswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        _transferFrom(
            ITransferAgent.ERC20TransferType.SwapToken,
            path[0],
            msg.sender,
            FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    /// @notice Swaps tokens for an exact amount of output tokens
    /// @dev Ensures maximum input amount is not exceeded and handles token transfer
    /// @param amountOut Exact amount of output tokens to receive
    /// @param amountInMax Maximum amount of input tokens to spend
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the output tokens
    /// @param deadline Deadline for the transaction
    /// @return amounts Array of input/output amounts for each swap in the path
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        (uint feeRate, uint denominator) = _getFeeRate();
        amounts = FragmentswapV2Library.getAmountsIn(factory, amountOut, path, feeRate, denominator, _initCodeHash);
        require(amounts[0] <= amountInMax, "FragmentswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        _transferFrom(
            ITransferAgent.ERC20TransferType.SwapToken,
            path[0],
            msg.sender,
            FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    /// @notice Swaps an exact amount of ETH for as many output tokens as possible
    /// @dev Requires first token in path to be WETH and handles ETH wrapping
    /// @param amountOutMin Minimum amount of output tokens to receive
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the output tokens
    /// @param deadline Deadline for the transaction
    /// @return amounts Array of input/output amounts for each swap in the path
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "FragmentswapV2Router: INVALID_PATH");
        (uint feeRate, uint denominator) = _getFeeRate();
        amounts = FragmentswapV2Library.getAmountsOut(factory, msg.value, path, feeRate, denominator, _initCodeHash);
        require(amounts[amounts.length - 1] >= amountOutMin, "FragmentswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash), amounts[0])
        );
        _swap(amounts, path, to);
    }

    /// @notice Swaps tokens for an exact amount of ETH
    /// @dev Requires last token in path to be WETH and handles ETH unwrapping
    /// @param amountOut Exact amount of ETH to receive
    /// @param amountInMax Maximum amount of input tokens to spend
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the ETH
    /// @param deadline Deadline for the transaction
    /// @return amounts Array of input/output amounts for each swap in the path
    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "FragmentswapV2Router: INVALID_PATH");
        (uint feeRate, uint denominator) = _getFeeRate();
        amounts = FragmentswapV2Library.getAmountsIn(factory, amountOut, path, feeRate, denominator, _initCodeHash);
        require(amounts[0] <= amountInMax, "FragmentswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        _transferFrom(
            ITransferAgent.ERC20TransferType.SwapToken,
            path[0],
            msg.sender,
            FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /// @notice Swaps an exact amount of tokens for as much ETH as possible
    /// @dev Requires last token in path to be WETH and handles ETH unwrapping
    /// @param amountIn Exact amount of input tokens to send
    /// @param amountOutMin Minimum amount of ETH to receive
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the ETH
    /// @param deadline Deadline for the transaction
    /// @return amounts Array of input/output amounts for each swap in the path
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "FragmentswapV2Router: INVALID_PATH");
        (uint feeRate, uint denominator) = _getFeeRate();
        amounts = FragmentswapV2Library.getAmountsOut(factory, amountIn, path, feeRate, denominator, _initCodeHash);
        require(amounts[amounts.length - 1] >= amountOutMin, "FragmentswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        _transferFrom(
            ITransferAgent.ERC20TransferType.SwapToken,
            path[0],
            msg.sender,
            FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /// @notice Swaps ETH for an exact amount of tokens
    /// @dev Requires first token in path to be WETH and handles ETH wrapping
    /// @param amountOut Exact amount of output tokens to receive
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the output tokens
    /// @param deadline Deadline for the transaction
    /// @return amounts Array of input/output amounts for each swap in the path
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "FragmentswapV2Router: INVALID_PATH");
        (uint feeRate, uint denominator) = _getFeeRate();
        amounts = FragmentswapV2Library.getAmountsIn(factory, amountOut, path, feeRate, denominator, _initCodeHash);
        require(amounts[0] <= msg.value, "FragmentswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash), amounts[0])
        );
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    /// @notice Internal function to swap tokens supporting fee-on-transfer tokens
    /// @dev Handles the actual token swaps when dealing with fee-on-transfer tokens
    /// @param path Array of token addresses representing the swap path
    /// @param _to Address to receive the output tokens
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FragmentswapV2Library.sortTokens(input, output);
            IFragmentSwapPair pair = IFragmentSwapPair(
                FragmentswapV2Library.pairFor(factory, input, output, _initCodeHash)
            );
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint feeRate, uint denominator) = _getFeeRate();
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = FragmentswapV2Library.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput,
                    feeRate,
                    denominator
                );
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2
                ? FragmentswapV2Library.pairFor(factory, output, path[i + 2], _initCodeHash)
                : _to;
            pair.swap(uint112(amount0Out), uint112(amount1Out), to, new bytes(0));
        }
    }

    /// @notice Swap exact input tokens for output tokens supporting fee-on-transfer tokens
    /// @dev Swaps an exact amount of input tokens for as many output tokens as possible
    /// @param amountIn Exact amount of input tokens to swap
    /// @param amountOutMin Minimum amount of output tokens expected
    /// @param path Array of token addresses representing the swap path
    /// @param to Address to receive the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        _transferFrom(
            ITransferAgent.ERC20TransferType.SwapToken,
            path[0],
            msg.sender,
            FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash),
            amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "FragmentswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    /// @notice Swap exact ETH for tokens supporting fee-on-transfer tokens
    /// @dev Swaps an exact amount of ETH for as many output tokens as possible
    /// @param amountOutMin Minimum amount of output tokens expected
    /// @param path Array of token addresses representing the swap path (first element must be WETH)
    /// @param to Address to receive the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WETH, "FragmentswapV2Router: INVALID_PATH");
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "FragmentswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    /// @notice Swap exact tokens for ETH supporting fee-on-transfer tokens
    /// @dev Swaps an exact amount of input tokens for as much ETH as possible
    /// @param amountIn Exact amount of input tokens to swap
    /// @param amountOutMin Minimum amount of ETH expected
    /// @param path Array of token addresses representing the swap path (last element must be WETH)
    /// @param to Address to receive the ETH
    /// @param deadline Unix timestamp after which the transaction will revert
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, "FragmentswapV2Router: INVALID_PATH");
        _transferFrom(
            ITransferAgent.ERC20TransferType.SwapToken,
            path[0],
            msg.sender,
            FragmentswapV2Library.pairFor(factory, path[0], path[1], _initCodeHash),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, "FragmentswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    /// @notice Given an input asset amount, returns the maximum output amount of the other asset
    /// @param amountA Amount of input asset
    /// @param reserveA Reserve of input asset in the pair
    /// @param reserveB Reserve of output asset in the pair
    /// @return amountB Maximum output amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return FragmentswapV2Library.quote(amountA, reserveA, reserveB);
    }

    /// @notice Given an input amount and reserves, returns the output amount after fees
    /// @param amountIn Amount of input asset
    /// @param reserveIn Reserve of input asset in the pair
    /// @param reserveOut Reserve of output asset in the pair
    /// @return amountOut Output amount after fees
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public view virtual override returns (uint amountOut) {
        (uint feeRate, uint denominator) = _getFeeRate();
        return FragmentswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut, feeRate, denominator);
    }

    /// @notice Given an output amount and reserves, returns the required input amount
    /// @param amountOut Desired output amount
    /// @param reserveIn Reserve of input asset in the pair
    /// @param reserveOut Reserve of output asset in the pair
    /// @return amountIn Required input amount
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public view virtual override returns (uint amountIn) {
        (uint feeRate, uint denominator) = _getFeeRate();
        return FragmentswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut, feeRate, denominator);
    }

    /// @notice Given an input amount and path, returns the output amounts along the path
    /// @param amountIn Amount of input asset
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of output amounts for each pair along the path
    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        (uint feeRate, uint denominator) = _getFeeRate();
        return FragmentswapV2Library.getAmountsOut(factory, amountIn, path, feeRate, denominator, _initCodeHash);
    }

    /// @notice Given an output amount and path, returns the input amounts along the path
    /// @param amountOut Desired output amount
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of input amounts for each pair along the path
    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        (uint feeRate, uint denominator) = _getFeeRate();
        return FragmentswapV2Library.getAmountsIn(factory, amountOut, path, feeRate, denominator, _initCodeHash);
    }

    function predictPair(address tokenA, address tokenB) public view returns (address) {
        return FragmentswapV2Library.pairFor(factory, tokenA, tokenB, _initCodeHash);
    }
}
