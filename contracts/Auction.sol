// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/INFT.sol";
import "./interfaces/IRegistry.sol";

contract Auction is ERC721Holder, ERC1155Holder, Ownable {
    using SafeERC20 for IERC20;
    uint128 public auctionIdCounter; // _autionId starts from 1

    // address alias for using ETH as a currency
    address private constant ETH =
        address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
    IRegistry private immutable _REGISTRY;

    /*EVENTS*/
    event NewAuction(uint256 indexed auctionId, AuctionInfo newAuction);
    event AuctionCancelled(uint256 indexed auctionId);
    event BidPlaced(uint256 indexed auctionId, uint256 totalAmount);
    event ClaimAuctionNFT(
        uint256 indexed auctionId,
        address indexed claimer,
        address indexed recipient,
        uint256 amount
    );
    event BalanceUpdated(
        address indexed accountOf,
        address indexed tokenAddress,
        uint256 indexed newBalance
    );

    error AuctionIsNotActive();
    error BidIsNotHighEnough();
    error BidLoweThanReservePrice();
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
        uint128 id; // auctionId
        uint128 nftId;
        bool isERC721;
        address nftAddress;
        address owner; // NFT owner address
        address currency; // use zero address or 0xeee for ETH
        uint256 startTime;
        uint256 endTime;
        uint256 reservePrice; // may need to be made private
    }

    struct Bid {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => AuctionInfo) public auctions; // auctionId => AuctionInfo
    mapping(uint256 => bool) public cancelledAuction; // auctionId => status
    mapping(uint256 => bool) public claimed; // auctionId => status
    mapping(uint256 => address) public highestBidder; // auctionId => highest bidder address
    mapping(address => uint256) public escrow; // currency address => escrow amount
    // auctionId => bidderAddress => Bid
    mapping(uint256 => mapping(address => Bid)) public bids;
    // userAddress => tokenAddress => amount
    mapping(address => mapping(address => uint256)) public claimableFunds;

    constructor(address registry) {
        _REGISTRY = IRegistry(registry);
    }

    function getAuctions(
        uint256 pageNo,
        uint256 pageSize
    ) public view returns (AuctionInfo[] memory) {
        uint256 auctionLength = auctionIdCounter;
        uint256 startIndex = (pageNo - 1) * pageSize;
        uint256 endIndex = startIndex + pageSize;

        if (startIndex >= auctionLength) {
            return new AuctionInfo[](0);
        }

        if (endIndex > auctionLength) {
            endIndex = auctionLength;
        }

        uint256 resultLength = endIndex - startIndex;
        AuctionInfo[] memory auctionInfos = new AuctionInfo[](resultLength);

        for (uint256 i = startIndex; i < endIndex; i++) {
            auctionInfos[i - startIndex] = auctions[i];
        }

        return auctionInfos;
    }

    function createAuction(
        bool isERC721,
        address nftAddress,
        uint128 nftId,
        uint256 startTime,
        uint256 endTime,
        uint256 reservePrice,
        address currency
    ) external returns (uint128 auctionId) {
        _beforeSaleOrAuction(nftAddress, startTime, endTime, currency);
        INFT nftContract = INFT(nftAddress);

        // transfer the nft to the platform
        isERC721
            ? nftContract.safeTransferFrom(msg.sender, address(this), nftId, "")
            : nftContract.safeTransferFrom(
                msg.sender,
                address(this),
                nftId,
                1,
                ""
            );

        // save auction info
        unchecked {
            ++auctionIdCounter;
        }

        auctionId = auctionIdCounter;
        auctions[auctionId] = AuctionInfo({
            isERC721: isERC721,
            id: auctionId,
            owner: msg.sender,
            nftAddress: nftAddress,
            nftId: nftId,
            startTime: startTime,
            endTime: endTime,
            reservePrice: reservePrice,
            currency: currency
        });

        emit NewAuction(auctionId, auctions[auctionId]);
    }

    function bid(
        uint256 auctionId,
        uint256 amountFromBalance,
        uint256 externalFunds
    ) external payable returns (bool) {
        if (getAuctionStatus(auctionId) != "ACTIVE")
            revert AuctionIsNotActive();

        uint256 totalAmount = amountFromBalance +
            externalFunds +
            // this allows the top bidder to top off their bid
            bids[auctionId][msg.sender].amount;

        if (totalAmount <= bids[auctionId][highestBidder[auctionId]].amount)
            revert BidIsNotHighEnough();
        if (totalAmount < auctions[auctionId].reservePrice)
            revert BidLoweThanReservePrice();

        address currency = auctions[auctionId].currency;
        if (amountFromBalance > claimableFunds[msg.sender][currency])
            revert NotEnoughBalance();

        if (currency != ETH) {
            IERC20 token = IERC20(currency);
            token.safeTransferFrom(msg.sender, address(this), externalFunds);
        } else {
            if (msg.value != externalFunds) revert ArgumentsAndValueMismatch();
        }

        // next highest bid can be made claimable now,
        // also helps for figuring out how much more net is in escrow
        address lastHighestBidder = highestBidder[auctionId];
        uint256 lastHighestAmount = bids[auctionId][lastHighestBidder].amount;
        escrow[currency] += totalAmount - lastHighestAmount;

        // last bidder can claim their fund now
        if (lastHighestBidder != msg.sender) {
            delete bids[auctionId][lastHighestBidder].amount;
            claimableFunds[lastHighestBidder][currency] += lastHighestAmount;

            emit BalanceUpdated(
                lastHighestBidder,
                currency,
                claimableFunds[lastHighestBidder][currency]
            );
        }
        if (amountFromBalance != 0) {
            claimableFunds[msg.sender][currency] -= amountFromBalance;

            emit BalanceUpdated(msg.sender, currency, amountFromBalance);
        }

        bids[auctionId][msg.sender].amount = totalAmount;
        bids[auctionId][msg.sender].timestamp = block.timestamp;
        highestBidder[auctionId] = msg.sender;

        emit BidPlaced(auctionId, totalAmount);
        return true;
    }

    function resolveAuction(uint256 auctionId) external {
        bytes32 status = getAuctionStatus(auctionId);
        if (status != "CANCELLED" && status != "ENDED")
            revert AuctionIsNotEndOrCancelled();

        uint256 nftId = auctions[auctionId].nftId;
        address owner = auctions[auctionId].owner;
        address highestBidder_ = highestBidder[auctionId];
        uint256 winningBid = bids[auctionId][highestBidder_].amount;
        uint256 totalFundsToPay = msg.sender == owner ? 0 : winningBid;
        INFT nftContract = INFT(auctions[auctionId].nftAddress);

        // accounting logic
        address recipient;
        if (totalFundsToPay != 0) {
            _nftPayment(auctionId, winningBid, nftContract);
            recipient = highestBidder_;
        } else {
            recipient = owner;
        }
        auctions[auctionId].isERC721
            ? nftContract.safeTransferFrom(address(this), recipient, nftId, "")
            : nftContract.safeTransferFrom(
                address(this),
                recipient,
                nftId,
                1,
                ""
            );

        claimed[auctionId] = true;

        emit ClaimAuctionNFT(
            auctions[auctionId].id,
            msg.sender,
            recipient,
            bids[auctionId][highestBidder_].amount
        );
    }

    function cancelAuction(uint256 auctionId) external {
        if (msg.sender != auctions[auctionId].owner && msg.sender != owner())
            revert OnlyOwnerOrAuctionCreator();

        bytes32 status = getAuctionStatus(auctionId);
        if (status != "ACTIVE" && status != "PENDING")
            revert AuctionMustBeActiveOrPending();

        cancelledAuction[auctionId] = true;

        address currency = auctions[auctionId].currency;
        address highestBidder_ = highestBidder[auctionId];
        uint256 highestBid = bids[auctionId][highestBidder_].amount;

        // current highest bid moves from escrow to being reclaimable
        escrow[currency] -= highestBid;
        claimableFunds[highestBidder_][currency] += highestBid;

        emit BalanceUpdated(
            highestBidder_,
            currency,
            claimableFunds[highestBidder_][currency]
        );
        emit AuctionCancelled(auctionId);
    }

    function getAuctionStatus(uint256 auctionId) public view returns (bytes32) {
        if (auctionId > auctionIdCounter || auctionId == 0)
            revert AuctionDoesNotExist();

        if (
            cancelledAuction[auctionId]
            // || !_REGISTRY.platformContracts(address(this))
        ) return "CANCELLED";

        if (claimed[auctionId]) return "ENDED & CLAIMED";

        uint256 startTime = auctions[auctionId].startTime;
        uint256 endTime = auctions[auctionId].endTime;

        if (block.timestamp < startTime) return "PENDING";

        if (block.timestamp >= startTime && block.timestamp < endTime)
            return "ACTIVE";

        if (block.timestamp > endTime) return "ENDED";

        revert UnexpectedError();
    }

    function _beforeSaleOrAuction(
        address nftAddress,
        uint256 startTime,
        uint256 endTime,
        address currency
    ) private view {
        if (!_REGISTRY.approvedCurrencies(currency))
            revert CurrencyIsNotSupported();
        if (!INFT(nftAddress).supportsInterface(0x2a55205a))
            revert ContractMustSupportERC2981();
        if (endTime <= startTime) revert EndTimeMustBeGreaterThanStartTime();
    }

    function _nftPayment(
        uint256 auctionId,
        uint256 fundsToPay,
        INFT nftContract
    ) private {
        address currency = auctions[auctionId].currency;

        escrow[currency] -= fundsToPay;
        // if this is from a successful auction
        (address artistAddress, uint256 royalties) = nftContract.royaltyInfo(
            auctions[auctionId].nftId,
            fundsToPay
        );

        // system fee
        (address systemWallet, uint256 fee) = _REGISTRY.feeInfo(fundsToPay);
        unchecked {
            fundsToPay -= fee;
        }
        claimableFunds[systemWallet][currency] += fee;

        emit BalanceUpdated(
            systemWallet,
            currency,
            claimableFunds[systemWallet][currency]
        );

        // artist royalty if artist isn't the seller
        if (auctions[auctionId].owner != artistAddress) {
            unchecked {
                fundsToPay -= royalties;
            }
            claimableFunds[artistAddress][currency] += royalties;

            emit BalanceUpdated(
                artistAddress,
                currency,
                claimableFunds[artistAddress][currency]
            );
        }

        // seller gains
        claimableFunds[auctions[auctionId].owner][
            auctions[auctionId].currency
        ] += fundsToPay;

        emit BalanceUpdated(
            auctions[auctionId].owner,
            auctions[auctionId].currency,
            claimableFunds[auctions[auctionId].owner][
                auctions[auctionId].currency
            ]
        );
    }
}
