// SPDX-License-Identifier: GNU GPLv3

/// @title FractionSwap Factory Contract
/// @notice Factory contract for creating and managing FragmentSwap pairs
/// @dev Implements the IFragmentSwapFactory interface to create and track token pairs

import {FragmentSwapPairProxy} from "./FragmentSwapPairProxy.sol";
import {IFragmentSwapFactory} from "./interfaces/IFragmentSwapFactory.sol";
import {IFragmentSwapPair} from "./interfaces/IFragmentSwapPair.sol";

import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";

pragma solidity ^0.8.22;

/// @title FractionSwap Factory
/// @notice Creates and manages FragmentSwap token pairs
/// @dev Uses CREATE2 to deploy pair proxies with deterministic addresses
contract FractionSwapFactory is IFragmentSwapFactory {
    /// @notice Address of the setting contract
    address public immutable setting;

    address public immutable transferAgent;

    /// @notice Mapping of token addresses to pair addresses
    mapping(address => mapping(address => address)) public getPair;

    /// @notice Array of all created pair addresses
    address[] public allPairs;

    /// @notice Mapping to check if an address is a valid pair
    mapping(address => bool) public pairsExists;

    /// @dev Initialization data for pair proxies
    bytes private initData;

    /// @notice Immutable hash of the pair creation code
    bytes32 public immutable initCodeHash;

    /// @notice Constructs the FractionSwapFactory contract
    /// @param _setting Address of the setting contract
    /// @dev Initializes the factory with setting contract and calculates initCodeHash
    constructor(address _setting, address _transferAgent) {
        setting = _setting;
        transferAgent = _transferAgent;
        address initialLogic = IFractionManager(setting).getFragmentSwapPairLogic();
        require(initialLogic != address(0), "FractionSwapFactory: NO_LOGIC_SET");
        initData = abi.encode(initialLogic, _setting);

        bytes memory bytecode = type(FragmentSwapPairProxy).creationCode;
        bytes memory creationCode = abi.encodePacked(bytecode, initData);
        initCodeHash = keccak256(creationCode);
    }

    /// @notice Gets the number of pairs created by this factory
    /// @return The length of the allPairs array
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /// @notice Creates a new pair for two tokens
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @return pair Address of the newly created pair
    /// @dev Uses CREATE2 to deploy pair with deterministic address
    ///      Emits PairCreated event on success
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "FragmentswapV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "FragmentswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "FragmentswapV2: PAIR_EXISTS"); // single check is sufficient

        bytes memory bytecode = type(FragmentSwapPairProxy).creationCode;
        bytes memory creationCode = abi.encodePacked(bytecode, initData);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }

        require(pair != address(0), "FragmentswapV2: CREATE2_FAILED");
        IFragmentSwapPair(pair).initialize(token0, token1, setting, transferAgent);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        pairsExists[pair] = true;
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
