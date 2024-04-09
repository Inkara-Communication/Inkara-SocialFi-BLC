// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/INFT.sol";
import "./interfaces/IRegistry.sol";

contract Marketplace is ERC721Holder, ERC1155Holder, Ownable {
    using SafeERC20 for IERC20;
    uint128 public saleIdCounter; // saleIdCounter starts from 1

    // address alias for using ETH as a currency
    address private constant ETH =
        address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
    IRegistry private immutable _REGISTRY;

    event SaleCreated(
        uint256 indexed id,
        address indexed nftAddress,
        uint256 indexed nftID
    );
    event SaleCancelled(uint256 indexed saleId);
    event Purchase(
        uint256 indexed saleId,
        address indexed purchaser,
        address indexed recipient
    );
    event ClaimSaleNFTs(
        uint256 indexed id,
        address indexed owner,
        uint256 indexed amount
    );
    event ClaimFunds(
        address indexed accountOf,
        address indexed tokenAddress,
        uint256 indexed newBalance
    );

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
        uint128 nftId;
        bool isERC721;
        address nftAddress;
        address owner;
        address currency; // use zero address or 0xaaa for ETH
        uint256 amount; // amount of NFTs being sold
        uint256 purchased; // amount of NFTs purchased thus far
        uint256 startTime;
        uint256 endTime;
        uint256 price;
    }

    mapping(uint256 => SaleInfo) public sales; // saleId => saleInfo
    mapping(uint256 => bool) public cancelledSale; // saleId => status
    mapping(address => uint256) public escrow; // currency address => escrow amount
    // saleId => purchaserAddress => amountPurchased
    mapping(uint256 => mapping(address => uint256)) public purchased;
    // userAddress => tokenAddress => amount
    mapping(address => mapping(address => uint256)) public claimableFunds;

    /*CONSTRUCTOR*/

    constructor(address registry) {
        _REGISTRY = IRegistry(registry);
    }

    function createSale(
        bool isERC721,
        address nftAddress,
        uint128 nftId,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        address currency
    ) external returns (uint256 saleId) {
        _beforeSaleOrAuction(nftAddress, startTime, endTime, currency);
        if (isERC721 && amount != 1) revert CanOnlySellOneNFT();

        INFT nftContract = INFT(nftAddress);

        // transfer nft to the platform
        isERC721
            ? nftContract.safeTransferFrom(msg.sender, address(this), nftId, "")
            : nftContract.safeTransferFrom(
                msg.sender,
                address(this),
                nftId,
                amount,
                ""
            );

        // save the sale info
        unchecked {
            ++saleIdCounter;
        }

        saleId = saleIdCounter;
        sales[saleId] = SaleInfo({
            isERC721: isERC721,
            nftAddress: nftAddress,
            nftId: nftId,
            owner: msg.sender,
            amount: amount,
            purchased: 0,
            startTime: startTime,
            endTime: endTime,
            price: price,
            currency: currency
        });

        emit SaleCreated(saleId, nftAddress, nftId);
    }

    function getSales(
        uint256 pageNo,
        uint256 pageSize
    ) public view returns (SaleInfo[] memory) {
        uint256 salesLength = saleIdCounter;
        uint256 startIndex = (pageNo - 1) * pageSize;
        uint256 endIndex = startIndex + pageSize;

        if (startIndex >= salesLength) {
            return new SaleInfo[](0);
        }

        if (endIndex > salesLength) {
            endIndex = salesLength;
        }

        uint256 resultLength = endIndex - startIndex;
        SaleInfo[] memory saleInfos = new SaleInfo[](resultLength);

        for (uint256 i = startIndex; i < endIndex; i++) {
            saleInfos[i - startIndex] = sales[i + 1];
        }

        return saleInfos;
    }

    function claimFunds(address tokenAddress) external {
        uint256 payout = claimableFunds[msg.sender][tokenAddress];
        if (payout == 0) revert NothingToClaim();

        if (tokenAddress != ETH) {
            delete claimableFunds[msg.sender][tokenAddress];
            IERC20(tokenAddress).safeTransfer(msg.sender, payout);
        } else {
            delete claimableFunds[msg.sender][tokenAddress];

            (bool success, ) = msg.sender.call{value: payout}("");
            // bubble up the error meassage if the transfer fails
            if (!success) {
                assembly {
                    let ptr := mload(0x40)
                    let size := returndatasize()
                    returndatacopy(ptr, 0, size)
                    revert(ptr, size)
                }
            }
        }

        emit ClaimFunds(msg.sender, tokenAddress, payout);
    }

    function buy(
        uint256 saleId,
        address recipient,
        uint256 amountToBuy,
        uint256 amountFromBalance
    ) external payable returns (bool) {
        if (getSaleStatus(saleId) != "ACTIVE") revert SaleIsNotActive();

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

        SaleInfo memory saleInfo = sales[saleId];
        if (amountToBuy > saleInfo.amount - saleInfo.purchased)
            revert NotEnoughStock();

        address currency = saleInfo.currency;
        IERC20 token = IERC20(currency);
        INFT nftContract = INFT(saleInfo.nftAddress);

        if (token.balanceOf(msg.sender) < (amountToBuy * saleInfo.price)) {
            revert NotEnoughBalance();
        }
        (address artistAddress, uint256 royalties) = nftContract.royaltyInfo(
            saleInfo.nftId,
            amountToBuy * saleInfo.price
        );

        // system fee
        (address systemWallet, uint256 fee) = _REGISTRY.feeInfo(
            amountToBuy * saleInfo.price
        );

        // update the sale info
        unchecked {
            sales[saleId].purchased += amountToBuy;
            purchased[saleId][msg.sender] += amountToBuy;
        }
        // send the nft price to the platform
        if (currency != ETH) {
            if (
                saleInfo.owner != artistAddress && artistAddress != address(0)
            ) {
                token.safeTransferFrom(
                    msg.sender,
                    saleInfo.owner,
                    (amountToBuy * saleInfo.price) - (fee + royalties)
                );
                token.safeTransferFrom(msg.sender, artistAddress, royalties);
            } else {
                // since the artist is the seller
                token.safeTransferFrom(
                    msg.sender,
                    saleInfo.owner,
                    (amountToBuy * saleInfo.price) - fee
                );
            }

            token.safeTransferFrom(msg.sender, systemWallet, fee);
        } else if (
            msg.value != (amountToBuy * saleInfo.price) - amountFromBalance
        ) revert InputValueAndPriceMismatch();

        // send the nft to the buyer
        saleInfo.isERC721
            ? nftContract.safeTransferFrom(
                address(this),
                recipient,
                saleInfo.nftId,
                ""
            )
            : nftContract.safeTransferFrom(
                address(this),
                recipient,
                saleInfo.nftId,
                amountToBuy,
                ""
            );

        emit Purchase(saleId, msg.sender, recipient);
        return true;
    }

    function claimSaleNfts(uint256 saleId) external {
        bytes32 status = getSaleStatus(saleId);
        if (status != "CANCELLED" && status != "ENDED")
            revert SaleIsNotClosed();

        address nftAddress = sales[saleId].nftAddress;
        uint256 nftId = sales[saleId].nftId;
        uint256 amount = sales[saleId].amount;
        uint256 salePurchased = sales[saleId].purchased;
        address owner = sales[saleId].owner;

        if (msg.sender != owner) revert OnlyNFTOwnerCanClaim();
        if (salePurchased == amount) revert StockAlreadySoldOrClaimed();

        uint256 stock = amount - salePurchased;
        // update the sale info and send the nfts back to the seller
        sales[saleId].purchased = amount;
        sales[saleId].isERC721
            ? INFT(nftAddress).safeTransferFrom(address(this), owner, nftId, "")
            : INFT(nftAddress).safeTransferFrom(
                address(this),
                owner,
                nftId,
                stock,
                ""
            );

        emit ClaimSaleNFTs(saleId, msg.sender, stock);
    }

    function cancelSale(uint256 saleId) external {
        if (msg.sender != sales[saleId].owner && msg.sender != owner())
            revert OnlyOwnerOrSaleCreator();

        bytes32 status = getSaleStatus(saleId);
        if (status != "ACTIVE" && status != "PENDING")
            revert SaleMustBeActiveOrPending();

        cancelledSale[saleId] = true;

        emit SaleCancelled(saleId);
    }

    function getSaleStatus(uint256 saleId) public view returns (bytes32) {
        if (saleId > saleIdCounter || saleId == 0) revert SaleDoesNotExist();

        if (
            cancelledSale[saleId]
        ) return "CANCELLED";

        SaleInfo memory saleInfo = sales[saleId];
        if (block.timestamp < saleInfo.startTime) return "PENDING";

        if (
            block.timestamp < saleInfo.endTime &&
            saleInfo.purchased < saleInfo.amount
        ) return "ACTIVE";

        if (
            block.timestamp >= saleInfo.endTime ||
            saleInfo.purchased == saleInfo.amount
        ) return "ENDED";

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
}
