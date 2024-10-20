// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/INFT.sol";
import "../token/InkCurrency.sol";

contract Marketplace is ERC721Holder, ERC1155Holder, Ownable {
    using SafeERC20 for IERC20;
    uint128 public saleIdCounter;
    InkaraCurrency public inkCurrency;

    event SaleCreated(
        uint256 indexed id,
        address indexed nft_address,
        uint256 indexed nft_id
    );
    event SaleCancelled(uint256 indexed sale_id);
    event Purchase(
        uint256 indexed sale_id,
        address indexed purchaser,
        address indexed recipient
    );
    event ClaimSaleNFTs(uint256 indexed id, address indexed owner);
    event ClaimFunds(address indexed account_of, uint256 indexed new_balance);

    error CanOnlySellOneNFT();
    error SaleIsNotActive();
    error NotEnoughStock();
    error NotEnoughBalance();
    error InputValueAndPriceMismatch();
    error SaleIsNotClosed();
    error OnlyNFTOwnerCanClaim();
    error StockAlreadySoldOrClaimed();
    error NothingToClaim();
    error OnlyOwnerOrSaleCreator();
    error SaleMustBeActiveOrPending();
    error SaleDoesNotExist();
    error CurrencyIsNotSupported();
    error ContractMustSupportERC2981();
    error EndTimeMustBeGreaterThanStartTime();
    error UnexpectedError();

    struct SaleInfo {
        uint256 nft_id;
        bool isERC721;
        address nft_address;
        address owner;
        bool has_purchased;
        uint256 start_time;
        uint256 end_time;
        uint256 price;
    }

    mapping(uint256 => SaleInfo) public sales; // sale_id => sale_info
    mapping(uint256 => bool) public cancelled_sale; // sale_id => status
    mapping(address => uint256) public escrow; // currency address => escrow amount
    // userAddress => amount
    mapping(address => uint256) public claimableFunds;

    /* CONSTRUCTOR */

    constructor(address _inkCurrency) {
        inkCurrency = InkaraCurrency(_inkCurrency);
    }

    function createSale(
        uint256 nft_id,
        bool isERC721,
        address nft_address,
        uint256 start_time,
        uint256 end_time,
        uint256 price
    ) external returns (uint256 sale_id) {
        _beforeSaleOrAuction(nft_address, start_time, end_time);
        if (isERC721) revert CanOnlySellOneNFT();

        INFT nftContract = INFT(nft_address);

        nftContract.safeTransferFrom(msg.sender, address(this), nft_id, "");

        unchecked {
            ++saleIdCounter;
        }

        sale_id = saleIdCounter;
        sales[sale_id] = SaleInfo({
            nft_id: nft_id,
            isERC721: isERC721,
            nft_address: nft_address,
            owner: msg.sender,
            has_purchased: false,
            start_time: start_time,
            end_time: end_time,
            price: price
        });

        emit SaleCreated(sale_id, nft_address, nft_id);
    }

    function getSales(
        uint256 pageNo,
        uint256 pageSize
    ) public view returns (SaleInfo[] memory) {
        uint256 sales_length = saleIdCounter;
        uint256 startIndex = (pageNo - 1) * pageSize;
        uint256 end_index = startIndex + pageSize;

        if (startIndex >= sales_length) {
            return new SaleInfo[](0);
        }

        if (end_index > sales_length) {
            end_index = sales_length;
        }

        uint256 resultLength = end_index - startIndex;
        SaleInfo[] memory saleInfos = new SaleInfo[](resultLength);

        for (uint256 i = startIndex; i < end_index; i++) {
            saleInfos[i - startIndex] = sales[i + 1];
        }

        return saleInfos;
    }

    function claimFunds() external {
        uint256 payout = claimableFunds[msg.sender];
        if (payout == 0) revert NothingToClaim();

        delete claimableFunds[msg.sender];
        inkCurrency.transferFrom(address(this), msg.sender, payout);

        emit ClaimFunds(msg.sender, payout);
    }

    function buy(uint256 sale_id, address recipient) external returns (bool) {
        if (getSaleStatus(sale_id) != "ACTIVE") revert SaleIsNotActive();

        assembly {
            if iszero(recipient) {
                let ptr := mload(0x40)
                mstore(
                    ptr,
                    0x8579befe00000000000000000000000000000000000000000000000000000000
                )
                revert(ptr, 0x4)
            }
        }

        SaleInfo memory sale_info = sales[sale_id];
        if (sale_info.has_purchased) revert NotEnoughStock();

        INFT nftContract = INFT(sale_info.nft_address);

        if (inkCurrency.balanceOf(msg.sender) < sale_info.price)
            revert NotEnoughBalance();

        (address artistAddress, uint256 royalties) = nftContract.royaltyInfo(
            sale_info.nft_id,
            sale_info.price
        );

        sales[sale_id].has_purchased = true;

        if (sale_info.owner != artistAddress && artistAddress != address(0)) {
            inkCurrency.transferFrom(
                msg.sender,
                sale_info.owner,
                sale_info.price - royalties
            );
            inkCurrency.transferFrom(msg.sender, artistAddress, royalties);
        } else {
            inkCurrency.transferFrom(
                msg.sender,
                sale_info.owner,
                sale_info.price
            );
        }

        nftContract.safeTransferFrom(
            address(this),
            recipient,
            sale_info.nft_id,
            ""
        );

        emit Purchase(sale_id, msg.sender, recipient);
        return true;
    }

    function claimSaleNfts(uint256 sale_id) external {
        bytes32 status = getSaleStatus(sale_id);
        if (status != "CANCELLED" && status != "ENDED")
            revert SaleIsNotClosed();

        address nft_address = sales[sale_id].nft_address;
        uint256 nft_id = sales[sale_id].nft_id;
        address owner = sales[sale_id].owner;

        if (msg.sender != owner) revert OnlyNFTOwnerCanClaim();

        // update the sale info and send the NFTs back to the seller
        sales[sale_id].has_purchased = false; // Reset has_purchased for the sale
        INFT(nft_address).safeTransferFrom(address(this), owner, nft_id, "");

        emit ClaimSaleNFTs(sale_id, msg.sender);
    }

    function cancelSale(uint256 sale_id) external {
        if (msg.sender != sales[sale_id].owner && msg.sender != owner())
            revert OnlyOwnerOrSaleCreator();

        bytes32 status = getSaleStatus(sale_id);
        if (status != "ACTIVE" && status != "PENDING")
            revert SaleMustBeActiveOrPending();

        cancelled_sale[sale_id] = true;

        emit SaleCancelled(sale_id);
    }

    function getSaleStatus(uint256 sale_id) public view returns (bytes32) {
        if (sale_id > saleIdCounter || sale_id == 0) revert SaleDoesNotExist();

        if (cancelled_sale[sale_id]) return "CANCELLED";

        SaleInfo memory sale_info = sales[sale_id];
        if (block.timestamp < sale_info.start_time) return "PENDING";

        if (block.timestamp < sale_info.end_time && !sale_info.has_purchased)
            return "ACTIVE";

        if (block.timestamp >= sale_info.end_time || sale_info.has_purchased)
            return "ENDED";

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
}
