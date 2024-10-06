// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/INFT.sol";
import "../token/InkCurrency.sol";

contract Auction is ERC721Holder, ERC1155Holder, Ownable {
    using SafeERC20 for IERC20;
    uint256 public auction_id_counter;
    InkaraCurrency public ink_currency;

    /*EVENTS*/
    event NewAuction(uint256 indexed auction_id, AuctionInfo new_auction);
    event AuctionCancelled(uint256 indexed auction_id);
    event BidPlaced(uint256 indexed auction_id, uint256 total_amount);
    event ClaimAuctionNFT(
        uint256 indexed auction_id,
        address indexed claimer,
        address indexed recipient,
        uint256 amount
    );
    event BalanceUpdated(
        address indexed account_of,
        uint256 indexed new_balance
    );

    error AuctionIsNotActive();
    error BidIsNotHighEnough();
    error BidLowerThanReservePrice();
    error ArgumentsAndValueMismatch();
    error AuctionIsNotEndOrCancelled();
    error OnlyOwnerOrAuctionCreator();
    error AuctionMustBeActiveOrPending();
    error NotEnoughBalance();
    error AuctionDoesNotExist();
    error NFTContractIsNotApproved();
    error CurrencyIsNotSupported();
    error ContractMustSupportERC2981();
    error EndTimeMustBeGreaterThanStartTime();
    error UnexpectedError();

    struct AuctionInfo {
        uint256 id; // auction_id
        uint256 nft_id;
        bool isERC721;
        address nft_address;
        address owner; // NFT owner address
        uint256 start_time;
        uint256 end_time;
        uint256 reserve_price; // may need to be made private
    }

    struct Bid {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => AuctionInfo) public auctions; // auction_id => AuctionInfo
    mapping(uint256 => bool) public cancelled_auction; // auction_id => status
    mapping(uint256 => bool) public claimed; // auction_id => status
    mapping(uint256 => address) public highest_bidder; // auction_id => highest bidder address
    // auction_id => bidderAddress => Bid
    mapping(uint256 => mapping(address => Bid)) public bids;
    // userAddress => amount
    mapping(address => uint256) public claimable_funds;

    /* CONSTRUCTOR */

    constructor(address _inkCurrency) {
        ink_currency = InkaraCurrency(_inkCurrency);
    }

    function getAuctions(
        uint256 page_no,
        uint256 page_size
    ) public view returns (AuctionInfo[] memory) {
        uint256 auction_length = auction_id_counter;
        uint256 start_index = (page_no - 1) * page_size;
        uint256 end_index = start_index + page_size;

        if (start_index >= auction_length) {
            return new AuctionInfo[](0);
        }

        if (end_index > auction_length) {
            end_index = auction_length;
        }

        uint256 result_length = end_index - start_index;
        AuctionInfo[] memory auction_infos = new AuctionInfo[](result_length);

        for (uint256 i = start_index; i < end_index; i++) {
            auction_infos[i - start_index] = auctions[i];
        }

        return auction_infos;
    }

    function createAuction(
        bool isERC721,
        address nft_address,
        uint256 nft_id,
        uint256 start_time,
        uint256 end_time,
        uint256 reserve_price
    ) external returns (uint256 auction_id) {
        _beforeSaleOrAuction(nft_address, start_time, end_time);
        INFT nftContract = INFT(nft_address);

        // transfer nft to the platform
        nftContract.safeTransferFrom(msg.sender, address(this), nft_id, "");

        // save auction info
        unchecked {
            ++auction_id_counter;
        }

        auction_id = auction_id_counter;
        auctions[auction_id] = AuctionInfo({
            id: auction_id,
            nft_id: nft_id,
            isERC721: isERC721,
            nft_address: nft_address,
            owner: msg.sender,
            start_time: start_time,
            end_time: end_time,
            reserve_price: reserve_price
        });

        emit NewAuction(auction_id, auctions[auction_id]);
    }

    function bid(
        uint256 auction_id,
        uint256 amountFromBalance,
        uint256 externalFunds
    ) external payable returns (bool) {
        if (getAuctionStatus(auction_id) != "ACTIVE")
            revert AuctionIsNotActive();
        uint256 total_amount = amountFromBalance +
            externalFunds +
            // this allows the top bidder to top off their bid
            bids[auction_id][msg.sender].amount;

        if (total_amount <= bids[auction_id][highest_bidder[auction_id]].amount)
            revert BidIsNotHighEnough();
        if (total_amount < auctions[auction_id].reserve_price)
            revert BidLowerThanReservePrice();

        if (amountFromBalance > claimable_funds[msg.sender])
            revert NotEnoughBalance();

        // Transfer external funds
        ink_currency.transferFrom(msg.sender, address(this), externalFunds);

        // next highest bid can be made claimable now
        address lastHighestBidder = highest_bidder[auction_id];
        uint256 lastHighestAmount = bids[auction_id][lastHighestBidder].amount;

        // last bidder can claim their fund now
        if (lastHighestBidder != msg.sender) {
            delete bids[auction_id][lastHighestBidder].amount;
            claimable_funds[lastHighestBidder] += lastHighestAmount;

            emit BalanceUpdated(
                lastHighestBidder,
                claimable_funds[lastHighestBidder]
            );
        }
        if (amountFromBalance != 0) {
            claimable_funds[msg.sender] -= amountFromBalance;

            emit BalanceUpdated(msg.sender, amountFromBalance);
        }

        bids[auction_id][msg.sender].amount = total_amount;
        bids[auction_id][msg.sender].timestamp = block.timestamp;
        highest_bidder[auction_id] = msg.sender;

        emit BidPlaced(auction_id, total_amount);
        return true;
    }

    function resolveAuction(uint256 auction_id) external {
        bytes32 status = getAuctionStatus(auction_id);
        if (status != "CANCELLED" && status != "ENDED")
            revert AuctionIsNotEndOrCancelled();

        uint256 nft_id = auctions[auction_id].nft_id;
        address owner = auctions[auction_id].owner;
        address highestBidder_ = highest_bidder[auction_id];
        uint256 winningBid = bids[auction_id][highestBidder_].amount;
        uint256 totalFundsToPay = msg.sender == owner ? 0 : winningBid;
        INFT nftContract = INFT(auctions[auction_id].nft_address);

        // accounting logic
        address recipient;
        if (totalFundsToPay != 0) {
            _nftPayment(auction_id, winningBid, nftContract);
            recipient = highestBidder_;
        } else {
            recipient = owner;
        }
        if(auctions[auction_id].isERC721) {
            nftContract.safeTransferFrom(address(this), recipient, nft_id, "");
        }

        claimed[auction_id] = true;

        emit ClaimAuctionNFT(
            auctions[auction_id].id,
            msg.sender,
            recipient,
            bids[auction_id][highestBidder_].amount
        );
    }

    function cancelAuction(uint256 auction_id) external {
        if (msg.sender != auctions[auction_id].owner && msg.sender != owner())
            revert OnlyOwnerOrAuctionCreator();

        bytes32 status = getAuctionStatus(auction_id);
        if (status != "ACTIVE" && status != "PENDING")
            revert AuctionMustBeActiveOrPending();

        cancelled_auction[auction_id] = true;

        address highestBidder_ = highest_bidder[auction_id];
        uint256 highestBid = bids[auction_id][highestBidder_].amount;

        claimable_funds[highestBidder_] += highestBid;

        emit BalanceUpdated(
            highestBidder_,
            claimable_funds[highestBidder_]
        );
        emit AuctionCancelled(auction_id);
    }

    function getAuctionStatus(uint256 auction_id) public view returns (bytes32) {
        if (auction_id > auction_id_counter || auction_id == 0)
            revert AuctionDoesNotExist();

        if (
            cancelled_auction[auction_id]
        ) return "CANCELLED";

        if (claimed[auction_id]) return "ENDED & CLAIMED";

        uint256 start_time = auctions[auction_id].start_time;
        uint256 end_time = auctions[auction_id].end_time;

        if (block.timestamp < start_time) return "PENDING";

        if (block.timestamp >= start_time && block.timestamp < end_time)
            return "ACTIVE";

        if (block.timestamp > end_time) return "ENDED";

        revert UnexpectedError();
    }

    function _beforeSaleOrAuction(
        address nft_address,
        uint256 start_time,
        uint256 end_time
    ) private view {
        if (!INFT(nft_address).supportsInterface(0x2a55205a))
            revert ContractMustSupportERC2981();
        if (end_time <= start_time) revert EndTimeMustBeGreaterThanStartTime();
    }

    function _nftPayment(
        uint256 auction_id,
        uint256 funds_to_pay,
        INFT nftContract
    ) private {
        // If this is from a successful auction
        (address artist_address, uint256 royalties) = nftContract.royaltyInfo(
            auctions[auction_id].nft_id,
            funds_to_pay
        );

        uint256 fee = (funds_to_pay * 100) / 10000; // Example fee calculation
        unchecked {
            funds_to_pay -= fee;
        }
        claimable_funds[owner()] += fee;

        emit BalanceUpdated(
            owner(),
            claimable_funds[owner()]
        );

        // Artist royalty if artist isn't the seller
        if (auctions[auction_id].owner != artist_address) {
            unchecked {
                funds_to_pay -= royalties;
            }
            claimable_funds[artist_address] += royalties;

            emit BalanceUpdated(
                artist_address,
                claimable_funds[artist_address]
            );
        }

        // Seller gains
        claimable_funds[auctions[auction_id].owner] += funds_to_pay;

        emit BalanceUpdated(
            auctions[auction_id].owner,
            claimable_funds[auctions[auction_id].owner]
        );
    }
}
