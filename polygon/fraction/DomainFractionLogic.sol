// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IDomainFraction} from "./interfaces/IDomainFraction.sol";
import {IFractionManager} from "../setting/interfaces/IFractionManager.sol";
import {IMultiSignatureWalletManager} from "../setting/interfaces/IMultiSignatureWalletManager.sol";
import {ITransferAgent} from "../transfer/interfaces/ITransferAgent.sol";

/// @title Domain Fraction Logic Contract
/// @notice Implements the logic for fractionalized NFT ownership and auction system
contract DomainFractionLogic is IDomainFraction, IERC721Receiver, ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Represents auction data for a specific ballot
    /// @param bidder Address of the highest bidder
    /// @param bidPrice Current highest bid price
    /// @param bidTime Timestamp of the highest bid
    /// @param auctionEndTime Timestamp when auction ends
    /// @param voteEndTime Timestamp when voting ends
    /// @param votePassed Whether the vote passed
    /// @param votes Total number of votes cast
    /// @param claimed Whether the NFT has been claimed
    /// @param voters Mapping of addresses that have voted
    struct AuctionData {
        address bidder;
        uint256 bidPrice;
        uint256 bidTime;
        uint256 auctionEndTime;
        uint256 voteEndTime;
        bool votePassed;
        uint256 votes;
        bool claimed;
        mapping(address => bool) voters;
    }

    bytes32 private constant FractionStorageLocal = keccak256("domain.fraction");

    /// @notice Storage structure for fraction contract state
    struct FractionStorage {
        address settingManager;
        address transferAgent;
        uint256 originalTotalSupply;
        address erc721Token;
        uint256 tokenId;
        address priceCurrency;
        uint256 reservePrice;
        uint256 voteDuration;
        uint256 auctionDuration;
        uint256 auctionDurationAdd;
        uint256 ballotBox;
        uint256 passVotes;
        mapping(uint256 => AuctionData) auctionDataMapping;
    }

    function _getFractionStorage() private pure returns (FractionStorage storage fs) {
        bytes32 slot = FractionStorageLocal;
        assembly {
            fs.slot := slot
        }
    }

    /// @notice Emitted when NFT is redeemed by the owner
    event Redeem(address owner, address nftAddress, uint256 tokenId);

    /// @notice Emitted when a new bid is started
    event BidStart(address bidder, address currency, uint256 bidPrice, uint256 ballotId);

    /// @notice Emitted when a vote is cast
    event VoteCast(address voter, uint256 votes, uint256 ballotId);

    /// @notice Emitted when a bid is increased
    event BidIncreased(address bidder, address currency, uint256 bidPrice, uint256 ballotId);

    /// @notice Emitted when a bid is refunded
    event BidRefunded(address bidder, address currency, uint256 bidPrice, uint256 ballotId);

    /// @notice Emitted when NFT is claimed by the winner
    event NFTClaimed(address winner, address nftAddress, uint256 tokenId, uint256 ballotId);

    /// @notice Emitted when funds are claimed by token holders
    event FundsClaimed(address holder, uint256 burnedAmount, address currency, uint256 fundsShare);

    /// @notice Emitted when a voter is removed
    event VoterRemoved(address voter, uint256 ballotId);

    /// @notice Emitted when service charge is collected
    event ServiceCharge(address receiver, address currency, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _settingManager Address of the setting manager contract
    /// @param _transferAgent Address of the transfer agent contract
    /// @param config ERC20 configuration parameters
    /// @param info ERC721 information parameters
    function initialize(
        address _settingManager,
        address _transferAgent,
        ERC20Config memory config,
        ERC721Info memory info
    ) public virtual initializer {
        require(config.originalTotalSupply > 0, "Invalid total supply");
        require(
            IMultiSignatureWalletManager(_settingManager).isSafeReceiver(config.initalReceiver),
            "Insecure receiving address"
        );

        IFractionManager.FractionConfig memory fractionConfig = IFractionManager(_settingManager)
            .getFractionConfigStruct();
        require(info.voteDuration >= fractionConfig.minVoteDuration, "Vote duration too low");
        require(info.voteDuration <= fractionConfig.maxVoteDuration, "Vote duration too high");
        require(info.auctionDuration >= fractionConfig.minAuctionDuration, "Auction duration too low");
        require(info.auctionDuration <= fractionConfig.maxAuctionDuration, "Auction duration too high");
        require(info.auctionDurationAdd > 1 minutes, "Auction duration add too low");

        __ERC20_init(config.name, config.symbol);

        FractionStorage storage fs = _getFractionStorage();
        fs.settingManager = _settingManager;
        fs.transferAgent = _transferAgent;
        fs.originalTotalSupply = config.originalTotalSupply;

        _mint(config.initalReceiver, config.originalTotalSupply);

        fs.erc721Token = info.erc721Token;
        fs.tokenId = info.tokenId;
        fs.priceCurrency = info.priceCurrency;
        fs.reservePrice = info.reservePrice;
        fs.voteDuration = info.voteDuration;
        fs.auctionDuration = info.auctionDuration;
        fs.auctionDurationAdd = info.auctionDurationAdd;
    }

    /// @notice Cancels the current auction and returns assets based on current stage
    /// @dev Only callable by multi-signature wallet
    function cancelAuction() external nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        require(IMultiSignatureWalletManager(fs.settingManager).isMultiSignatureWallet(msg.sender), "Not proxy wallet");

        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(!auction.claimed, "NFT already claimed");

        // Case 1: Voting phase or no active auction
        if (auction.auctionEndTime == 0) {
            // Refund bid if exists
            if (auction.bidPrice > 0 && auction.bidder != address(0)) {
                IERC20(fs.priceCurrency).safeTransfer(auction.bidder, auction.bidPrice);
                emit BidRefunded(auction.bidder, fs.priceCurrency, auction.bidPrice, currentBallot);
            }

            // Transfer NFT back to fraction holders (multi-sig wallet)
            IERC721(fs.erc721Token).safeTransferFrom(address(this), msg.sender, fs.tokenId);
            auction.claimed = true;

            emit Redeem(msg.sender, fs.erc721Token, fs.tokenId);
        }
        // Case 2: Auction phase
        else if (block.timestamp < auction.auctionEndTime) {
            // Refund current bid
            if (auction.bidPrice > 0 && auction.bidder != address(0)) {
                IERC20(fs.priceCurrency).safeTransfer(auction.bidder, auction.bidPrice);
                emit BidRefunded(auction.bidder, fs.priceCurrency, auction.bidPrice, currentBallot);
            }

            // Transfer NFT back to fraction holders (multi-sig wallet)
            IERC721(fs.erc721Token).safeTransferFrom(address(this), msg.sender, fs.tokenId);
            auction.claimed = true;

            emit Redeem(msg.sender, fs.erc721Token, fs.tokenId);
        }
        // Case 3: Auction ended but not claimed
        else {
            revert("Auction ended, use claimNFT or withdrawBid");
        }
    }

    /// @notice Redeems the NFT by burning all fractions
    /// @dev Only callable by the multi-signature wallet that holds all fractions
    function redeem() external {
        FractionStorage storage fs = _getFractionStorage();
        require(IMultiSignatureWalletManager(fs.settingManager).isMultiSignatureWallet(msg.sender), "Not proxy wallet");
        require(balanceOf(msg.sender) == fs.originalTotalSupply, "Insufficient fractions");
        _burn(msg.sender, fs.originalTotalSupply);
        IERC721(fs.erc721Token).safeTransferFrom(address(this), msg.sender, fs.tokenId);
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];
        auction.claimed = true;
        emit Redeem(msg.sender, fs.erc721Token, fs.tokenId);
    }

    /// @notice Starts a new bid for the NFT
    /// @param bidPrice The initial bid price
    /// @param isVote Whether to require voting before auction
    /// @dev Only callable by multi-signature wallet
    function startBid(uint256 bidPrice, bool isVote) external payable nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        require(IMultiSignatureWalletManager(fs.settingManager).isMultiSignatureWallet(msg.sender), "Not proxy wallet");
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(!auction.claimed, "NFT already claimed");
        require(auction.auctionEndTime == 0, "Auction ongoing");
        require(
            auction.voteEndTime == 0 || (block.timestamp >= auction.voteEndTime && !auction.votePassed),
            "Invalid bidding state"
        );

        _validateBidPrice(bidPrice, fs.reservePrice, true);
        _safeTransferERC20(bidPrice);
        _refundPreviousBidder(currentBallot);

        uint256 newBallotId = block.timestamp;
        fs.ballotBox = newBallotId;
        AuctionData storage newAuction = fs.auctionDataMapping[newBallotId];

        newAuction.bidder = msg.sender;
        newAuction.bidPrice = bidPrice;
        newAuction.bidTime = block.timestamp;
        newAuction.voteEndTime = block.timestamp + fs.voteDuration;
        newAuction.votePassed = !isVote;
        newAuction.claimed = false;
        IFractionManager.FractionConfig memory fractionConfig = IFractionManager(fs.settingManager)
            .getFractionConfigStruct();
        fs.passVotes = (fs.originalTotalSupply * fractionConfig.votePercentage) / fractionConfig.denominator;

        emit BidStart(msg.sender, fs.priceCurrency, bidPrice, newBallotId);

        if (!isVote) {
            newAuction.auctionEndTime = block.timestamp + fs.auctionDuration;
        }
    }

    /// @notice Casts a vote for the current auction
    /// @dev Only callable by token holders with voting power
    function vote() external nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(!auction.claimed, "NFT already claimed");
        require(auction.auctionEndTime == 0, "Auction ongoing");
        require(!auction.votePassed && block.timestamp < auction.voteEndTime, "Voting closed");
        require(!auction.voters[msg.sender], "Already voted");

        uint256 voterPower = balanceOf(msg.sender);
        require(voterPower > 0, "No voting power");

        auction.voters[msg.sender] = true;
        auction.votes += voterPower;

        if (auction.votes >= fs.passVotes) {
            auction.votePassed = true;
            auction.auctionEndTime = block.timestamp + fs.auctionDuration;
        }

        emit VoteCast(msg.sender, voterPower, currentBallot);
    }

    /// @notice Increases the current bid
    /// @param bidPrice The new bid price
    /// @dev Only callable by multi-signature wallet
    function increaseBid(uint256 bidPrice) external payable nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        require(IMultiSignatureWalletManager(fs.settingManager).isMultiSignatureWallet(msg.sender), "Not proxy wallet");
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(!auction.claimed, "NFT already claimed");
        require(auction.votePassed, "Vote not passed");
        require(auction.auctionEndTime >= block.timestamp, "Auction ended");
        require(auction.bidder != msg.sender, "Already highest bidder");

        _validateBidPrice(bidPrice, auction.bidPrice, true);
        _safeTransferERC20(bidPrice);
        _refundPreviousBidder(currentBallot);

        auction.bidder = msg.sender;
        auction.bidPrice = bidPrice;
        auction.bidTime = block.timestamp;

        if (auction.auctionEndTime - block.timestamp <= fs.auctionDurationAdd) {
            auction.auctionEndTime += fs.auctionDurationAdd;
        }

        emit BidIncreased(msg.sender, fs.priceCurrency, bidPrice, currentBallot);
    }

    /// @notice Withdraws bid when voting fails
    /// @dev Only callable by the bidder when voting fails
    function withdrawBid() external nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(
            auction.voteEndTime > 0 && block.timestamp >= auction.voteEndTime && !auction.votePassed,
            "Ineligible for refund"
        );
        require(msg.sender == auction.bidder, "Not bidder");

        uint256 refundAmount = auction.bidPrice;
        delete fs.auctionDataMapping[currentBallot];

        IERC20(fs.priceCurrency).safeTransfer(msg.sender, refundAmount);
        emit BidRefunded(msg.sender, fs.priceCurrency, refundAmount, currentBallot);
    }

    /// @notice Claims the NFT after successful auction
    /// @dev Only callable by the winning bidder
    function claimNFT() external nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(!auction.claimed, "NFT already claimed");
        require(auction.votePassed, "Vote failed");
        require(block.timestamp >= auction.auctionEndTime, "Auction ongoing");
        require(msg.sender == auction.bidder, "Not winner");

        _afterClaimNFT();
        IERC721(fs.erc721Token).safeTransferFrom(address(this), msg.sender, fs.tokenId);
        auction.claimed = true;
        emit NFTClaimed(msg.sender, fs.erc721Token, fs.tokenId, currentBallot);
    }

    /// @notice Claims funds proportional to burned tokens
    /// @param burnAmount Amount of tokens to burn
    /// @dev Only callable by multi-signature wallet
    function claimFunds(uint256 burnAmount) external nonReentrant {
        FractionStorage storage fs = _getFractionStorage();
        require(IMultiSignatureWalletManager(fs.settingManager).isMultiSignatureWallet(msg.sender), "Not proxy wallet");
        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];

        require(auction.votePassed && block.timestamp >= auction.auctionEndTime, "Invalid claim timing");
        require(auction.claimed, "NFT not claimed");

        uint256 vaultBalance = IERC20(fs.priceCurrency).balanceOf(address(this));
        uint256 remainingTotalSupply = totalSupply();
        uint256 share;
        if (remainingTotalSupply == burnAmount) {
            share = vaultBalance;
        } else {
            share = (vaultBalance * burnAmount) / totalSupply();
        }
        _burn(msg.sender, burnAmount);
        IERC20(fs.priceCurrency).safeTransfer(msg.sender, share);

        emit FundsClaimed(msg.sender, burnAmount, fs.priceCurrency, share);
    }

    /// @notice Gets the fraction storage details
    /// @return Tuple containing all storage fields
    function getFractionStorage()
        external
        view
        returns (
            address,
            address,
            uint256,
            address,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        FractionStorage storage fs = _getFractionStorage();
        return (
            fs.settingManager,
            fs.transferAgent,
            fs.originalTotalSupply,
            fs.erc721Token,
            fs.tokenId,
            fs.priceCurrency,
            fs.reservePrice,
            fs.voteDuration,
            fs.auctionDuration,
            fs.auctionDurationAdd,
            fs.ballotBox,
            fs.passVotes
        );
    }

    /// @notice Gets the current auction state
    /// @return Tuple containing auction state fields
    function getAuctionState()
        external
        view
        returns (address, uint256, uint256, uint256, uint256, bool, uint256, uint256, bool)
    {
        FractionStorage storage fs = _getFractionStorage();
        AuctionData storage auction = fs.auctionDataMapping[fs.ballotBox];
        return (
            auction.bidder,
            auction.bidPrice,
            auction.bidTime,
            auction.votes,
            fs.passVotes,
            auction.votePassed,
            auction.voteEndTime,
            auction.auctionEndTime,
            auction.claimed
        );
    }

    /// @notice Checks if an address has voted in current auction
    /// @param voter Address to check
    /// @return True if the address has voted
    function hasVoted(address voter) external view returns (bool) {
        FractionStorage storage fs = _getFractionStorage();
        return fs.auctionDataMapping[fs.ballotBox].voters[voter];
    }

    /// @notice ERC721 receiver interface implementation
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev Collects service charge when NFT is claimed
    function _afterClaimNFT() private {
        FractionStorage storage fs = _getFractionStorage();
        IFractionManager.FractionConfig memory config = IFractionManager(fs.settingManager).getFractionConfigStruct();
        if (config.serviceCharge == 0 || config.serviceChargeReceiver == address(0)) return;
        uint256 totalDeposit = IERC20(fs.priceCurrency).balanceOf(address(this));
        uint256 serviceCharge = (totalDeposit * config.serviceCharge) / config.denominator;
        IERC20(fs.priceCurrency).safeTransfer(config.serviceChargeReceiver, serviceCharge);
        emit ServiceCharge(config.serviceChargeReceiver, fs.priceCurrency, serviceCharge);
    }

    /// @dev Validates the bid price
    /// @param newPrice The new bid price
    /// @param comparisonPrice The price to compare against
    /// @param isIncrease Whether this is a bid increase
    function _validateBidPrice(uint256 newPrice, uint256 comparisonPrice, bool isIncrease) private view {
        FractionStorage storage fs = _getFractionStorage();
        if (isIncrease) {
            IFractionManager.FractionConfig memory config = IFractionManager(fs.settingManager)
                .getFractionConfigStruct();
            uint256 minIncrease = comparisonPrice +
                ((comparisonPrice * config.bidIncreasePercentage) / config.denominator);
            require(newPrice >= minIncrease, "Bid too low");
        } else {
            require(newPrice >= fs.reservePrice, "Below reserve");
        }
    }

    /// @dev Refunds the previous bidder
    /// @param ballotId ID of the ballot to refund
    function _refundPreviousBidder(uint256 ballotId) private {
        FractionStorage storage fs = _getFractionStorage();
        AuctionData storage auction = fs.auctionDataMapping[ballotId];
        if (auction.bidPrice > 0 && auction.bidder != address(0)) {
            IERC20(fs.priceCurrency).safeTransfer(auction.bidder, auction.bidPrice);
            emit BidRefunded(auction.bidder, fs.priceCurrency, auction.bidPrice, ballotId);
        }
    }

    /// @dev Safely transfers ERC20 tokens
    /// @param amount Amount to transfer
    function _safeTransferERC20(uint256 amount) private {
        FractionStorage storage fs = _getFractionStorage();
        ITransferAgent(fs.transferAgent).transferERC20(
            ITransferAgent.ERC20TransferType.FractionBid,
            fs.priceCurrency,
            msg.sender,
            address(this),
            amount
        );
    }

    /// @dev Handles token transfer updates
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    function _afterTokenTransfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) return;
        FractionStorage storage fs = _getFractionStorage();

        uint256 currentBallot = fs.ballotBox;
        AuctionData storage auction = fs.auctionDataMapping[currentBallot];
        if (auction.voteEndTime > block.timestamp && auction.voters[from]) {
            auction.votes -= amount;
            if (balanceOf(from) == 0) {
                auction.voters[from] = false;
                emit VoterRemoved(from, currentBallot);
            }
        }
    }

    /// @notice Returns the token decimals
    /// @return Number of decimals
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /// @notice Transfers tokens from one address to another
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    /// @return True if transfer is successful
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override(ERC20Upgradeable) returns (bool) {
        FractionStorage storage fs = _getFractionStorage();
        if (msg.sender == fs.transferAgent) {
            _transfer(from, to, amount);
        } else {
            super.transferFrom(from, to, amount);
        }
        return true;
    }

    /// @dev Updates token balances and handles voting power changes
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    function _update(address from, address to, uint256 amount) internal virtual override {
        super._update(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }
}
