import { expect } from "chai";
import { ethers } from "hardhat";
import { Creature, CreatureAccessory, Marketplace, RadesMockCurrency, Registry } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { promises } from "dns";
import exp from "constants";

describe("Rades Marketplace", function () {
  let Registry,
    RegistryInstance: Registry,
    Marketplace,
    MarketplaceInstance: Marketplace,
    CreatureAccessory,
    CreatureAccessoryInstance: CreatureAccessory,
    Creature,
    CreatureInstance: Creature,
    RadesMockCurrency,
    RadesMockCurrencyInstance: RadesMockCurrency,
    owner: SignerWithAddress,
    address1: SignerWithAddress,
    address2: SignerWithAddress,
    address3: SignerWithAddress;
  async function deployContract() {
    Registry = await ethers.getContractFactory("Registry")
    RegistryInstance = await Registry.deploy()

    Marketplace = await ethers.getContractFactory("Marketplace")
    MarketplaceInstance = await Marketplace.deploy(RegistryInstance.address)

    CreatureAccessory = await ethers.getContractFactory("CreatureAccessory")
    CreatureAccessoryInstance = await CreatureAccessory.deploy(MarketplaceInstance.address)

    Creature = await ethers.getContractFactory("Creature")
    CreatureInstance = await Creature.deploy(MarketplaceInstance.address)

    RadesMockCurrency = await ethers.getContractFactory("RadesMockCurrency")
    RadesMockCurrencyInstance = await RadesMockCurrency.deploy()

    const address = await ethers.getSigners();
    owner = address[0]
    address1 = address[1]
    address2 = address[2]
    address3 = address[3]
    return owner
  }


  it("Should set the right owner", async function () {
    const owner = await deployContract()
    expect(await RegistryInstance.owner()).to.equal(owner.address)
    expect(await MarketplaceInstance.owner()).to.equal(owner.address)
    expect(await CreatureAccessoryInstance.owner()).to.equal(owner.address)
    expect(await CreatureInstance.owner()).to.equal(owner.address)
    expect(await RadesMockCurrencyInstance.owner()).to.equal(owner.address)
  });

  it("Should approve for Registry", async function () {
    const tx = await RegistryInstance.setCurrencyStatus(RadesMockCurrencyInstance.address, true);
    const receipt = tx.wait();
    const events = (await receipt).events?.map(x => x.event)
    expect(events?.[0]).to.equal("CurrencyStatusChanged")
    expect(await RegistryInstance.approvedCurrencies(RadesMockCurrencyInstance.address)).to.equal(true)
  });

  it("Mint and Sale Creature (ERC721)", async function () {
    const tx = await CreatureInstance.connect(owner).safeMint(address1.address, 111)
    const receipt = await tx.wait()
    const tokenId = Number(receipt?.events?.[0]?.args?.tokenId)
    await CreatureInstance.connect(address1).approve(MarketplaceInstance.address, tokenId)
    const saleTx = await MarketplaceInstance.connect(address1).createSale(
      // isERC721:
      true,
      // nftAddress:
      CreatureInstance.address,
      // nftId:
      tokenId,
      // amount:
      1,
      // startTime:
      (await ethers.provider.getBlock(1)).timestamp,
      // endTime:
      (await ethers.provider.getBlock(1)).timestamp + (3 * 24 * 60 * 60 * 1000),
      // price:
      100,
      // currency:
      RadesMockCurrencyInstance.address
    );
    const saleReceipt = await saleTx.wait();
    const saleId = Number(saleReceipt.events?.[1]?.args?.id);
    const [_nftId,
      _isERC721,
      _nftAddress,
      _owner,
      _currency,
      _amount,
      _purchased,
      _startTime,
      _endTime,
      _price] = await MarketplaceInstance.sales(saleId)
    expect(_isERC721).to.equal(true)
    expect(_nftAddress).to.equal(CreatureInstance.address)
    expect(_amount).to.equal(1)
    expect(_price).to.equal(100)
    expect(await CreatureInstance.balanceOf(MarketplaceInstance.address)).to.equal(1);
    expect(await CreatureInstance.ownerOf(_nftId)).to.equal(MarketplaceInstance.address);
    expect(await CreatureInstance.balanceOf(address1.address)).to.equal(0);
  });
  it("Should Buy Sale Creature (ERC721)", async function () {
    const saleInfo = await MarketplaceInstance.sales(1)
    const nftId = saleInfo[0]
    const price = saleInfo[saleInfo.length - 1] as any
    const buyer = address2, seller = address1;
    await RadesMockCurrencyInstance.connect(owner).mint(buyer.address, 10_000);
    await RadesMockCurrencyInstance.connect(buyer).approve(MarketplaceInstance.address, 100)

    const buyTx = await MarketplaceInstance.connect(buyer).buy(
      // saleId
      1,
      // recipient
      address2.address,
      // amountToBuy
      1,
      // amountFromBalance
      0
    );
    const receiptBuy = (await buyTx).wait();
    const buyEvents = (await receiptBuy)?.events || [];
    const buyInfo = buyEvents[buyEvents?.length - 1]?.args;
    const [system, fee] = await RegistryInstance.feeInfo(price)

    expect(await RadesMockCurrencyInstance.balanceOf(system)).to.equal(fee)
    expect(await RadesMockCurrencyInstance.balanceOf(seller.address)).to.equal(price - Number(fee))
    expect(await RadesMockCurrencyInstance.balanceOf(buyer.address)).to.equal(10_000 - price)
    expect(await CreatureInstance.ownerOf(nftId)).to.equal(buyer.address)

  });
  it("Mint and Sale Creature Accessory (ERC1155)", async function () {
    const tx = await CreatureAccessoryInstance.connect(owner).mint(address1.address, 111, 10)
    const receipt = await tx.wait()
    const tokenId = Number(receipt?.events?.[0]?.args?.id)
    const amount = Number(receipt?.events?.[0]?.args?.value)
    await CreatureAccessoryInstance.connect(address1).setApprovalForAll(MarketplaceInstance.address, true)
    const saleTx = await MarketplaceInstance.connect(address1).createSale(
      // isERC721:
      false,
      // nftAddress:
      CreatureAccessoryInstance.address,
      // nftId:
      tokenId,
      // amount:
      amount,
      // startTime:
      (await ethers.provider.getBlock(1)).timestamp,
      // endTime:
      (await ethers.provider.getBlock(1)).timestamp + (3 * 24 * 60 * 60 * 1000),
      // price:
      100,
      // currency:
      RadesMockCurrencyInstance.address
    );
    const saleReceipt = await saleTx.wait();
    const saleId = Number(saleReceipt.events?.[1]?.args?.id);
    const [_nftId,
      _isERC721,
      _nftAddress,
      _owner,
      _currency,
      _amount,
      _purchased,
      _startTime,
      _endTime,
      _price] = await MarketplaceInstance.sales(saleId)
    expect(saleId).to.equal(2)
    expect(_isERC721).to.equal(false)
    expect(_nftAddress).to.equal(CreatureAccessoryInstance.address)
    expect(_amount).to.equal(amount)
    expect(_price).to.equal(100)
    expect(await CreatureAccessoryInstance.balanceOf(MarketplaceInstance.address, tokenId)).to.equal(amount);
    expect(await CreatureAccessoryInstance.balanceOf(address1.address, tokenId)).to.equal(0);
  });
  it("Should Buy Sale Creature Accessory (ERC1155)", async function () {
    const saleId = 2,
      amountBuy = 3,
      saleInfo = await MarketplaceInstance.sales(saleId),
      nftId = saleInfo[0],
      price = saleInfo[saleInfo.length - 1] as any,
      buyer = address2,
      seller = address1,
      oldSellerBalance = Number(await RadesMockCurrencyInstance.balanceOf(seller.address)),
      oldBuyerBalance = Number(await RadesMockCurrencyInstance.balanceOf(buyer.address));
    await RadesMockCurrencyInstance.connect(buyer).approve(MarketplaceInstance.address, 300)
    const orderStatus = await ethers.utils.parseBytes32String(await MarketplaceInstance.getSaleStatus(saleId))
    expect(orderStatus).to.equal("ACTIVE")
    const buyTx = await MarketplaceInstance.connect(buyer).buy(
      // saleId
      saleId,
      // recipient
      address2.address,
      // amountToBuy
      3,
      // amountFromBalance
      0
    );
    const receiptBuy = (await buyTx).wait();
    const buyEvents = (await receiptBuy)?.events || [];
    const buyInfo = buyEvents[buyEvents?.length - 1]?.args;
    const [system, fee] = await RegistryInstance.feeInfo(price * amountBuy)
    expect(await RadesMockCurrencyInstance.balanceOf(system)).to.equal(3 + Number(fee))
    expect(await RadesMockCurrencyInstance.balanceOf(seller.address)).to.equal(oldSellerBalance + price * amountBuy - Number(fee))
    expect(await RadesMockCurrencyInstance.balanceOf(buyer.address)).to.equal(oldBuyerBalance - price * amountBuy)
    expect(await CreatureAccessoryInstance.balanceOf(buyer.address, nftId)).to.equal(amountBuy)
  });
  it("Should get Sales transaction (ERC721)", async function () {
    const sales = await MarketplaceInstance.getSales(1, 2);
    expect(JSON.stringify(sales)).to.equal(
      JSON.stringify([await MarketplaceInstance.sales(1), await MarketplaceInstance.sales(2)])
    )
  });
  it("Should Allow for Create ", async function () {
    const sales = await MarketplaceInstance.getSales(1, 2);
    expect(JSON.stringify(sales)).to.equal(
      JSON.stringify([await MarketplaceInstance.sales(1), await MarketplaceInstance.sales(2)])
    )
  });

  // it("metadata has already been used to mint an NFT.", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture();

  //   const addr1InitialOwnerBalance = await instance.balanceOf(addr1.address)
  //   const addr2InitialOwnerBalance = await instance.balanceOf(addr2.address)
  //   var mintTokenErrorMessage: Error | null = null
  //   try {
  //     await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //     await instance.connect(addr2).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   } catch (error) {
  //     if (error instanceof Error) {
  //       mintTokenErrorMessage = error
  //     }
  //   }

  //   const addr1NewOwnerBalance = await instance.balanceOf(addr1.address)
  //   const addr2NewOwnerBalance = await instance.balanceOf(addr2.address)

  //   expect(addr1InitialOwnerBalance).to.equal(0)
  //   expect(addr1NewOwnerBalance).to.equal(1)
  //   expect(addr2InitialOwnerBalance).to.equal(0)
  //   expect(addr2NewOwnerBalance).to.equal(addr2InitialOwnerBalance)
  //   expect(mintTokenErrorMessage).not.be.null
  //   expect(mintTokenErrorMessage!!.message).to.contain("This metadata has already been used to mint an NFT.")

  // });

  // it("get tokens owned by me", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokensAddr1 = await instance.connect(addr1).getTokensOwnedByMe()
  //   let tokensAddr2 = await instance.connect(addr2).getTokensOwnedByMe()
  //   let tokenOwner = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokensAddr2).to.be.empty
  //   expect(tokenOwner).to.equal(addr1.address)

  //   expect(tokensAddr1[0]["tokenId"]).to.equal(DEFAULT_TOKEN_ID)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(DEFAULT_METADATA_CID)
  //   expect(tokensAddr1[0]["isExist"]).to.be.true
  // });

  // it("get paginated tokens owned by me", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()
  //   let token1MetadataCID = "123456a"
  //   let token2MetadataCID = "123456b"
  //   let token3MetadataCID = "123456c"
  //   let token4MetadataCID = "123456d"
  //   let token5MetadataCID = "123456e"
  //   let token6MetadataCID = "123456f"
  //   let countTokens = 3

  //   await instance.connect(addr1).mintToken(token1MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token2MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token3MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token4MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token5MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token6MetadataCID, DEFAULT_TOKEN_ROYALTY)

  //   let tokensAddr1 = await instance.connect(addr1).getPaginatedTokensOwnedByMe(countTokens)
  //   let tokensAddr2 = await instance.connect(addr2).getPaginatedTokensOwnedByMe(countTokens)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokensAddr1).to.be.length(countTokens)
  //   expect(tokensAddr2).to.be.empty
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(1)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(token1MetadataCID)
  //   expect(tokensAddr1[1]["tokenId"]).to.equal(2)
  //   expect(tokensAddr1[1]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[1]["metadataCID"]).to.equal(token2MetadataCID)
  //   expect(tokensAddr1[2]["tokenId"]).to.equal(3)
  //   expect(tokensAddr1[2]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[2]["metadataCID"]).to.equal(token3MetadataCID)
  // });

  // it("get paginated tokens owned by any account", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()
  //   let token1MetadataCID = "123456a"
  //   let token2MetadataCID = "123456b"
  //   let token3MetadataCID = "123456c"
  //   let token4MetadataCID = "123456d"
  //   let token5MetadataCID = "123456e"
  //   let token6MetadataCID = "123456f"
  //   let countTokens = 3

  //   await instance.connect(addr1).mintToken(token1MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token2MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token3MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token4MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token5MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token6MetadataCID, DEFAULT_TOKEN_ROYALTY)

  //   let tokensAddr1 = await instance.connect(addr2).getPaginatedTokensOwnedBy(addr1.address, countTokens)
  //   let tokensAddr2 = await instance.connect(addr1).getPaginatedTokensOwnedBy(addr2.address, countTokens)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokensAddr1).to.be.length(countTokens)
  //   expect(tokensAddr2).to.be.empty
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(1)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(token1MetadataCID)
  //   expect(tokensAddr1[1]["tokenId"]).to.equal(2)
  //   expect(tokensAddr1[1]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[1]["metadataCID"]).to.equal(token2MetadataCID)
  //   expect(tokensAddr1[2]["tokenId"]).to.equal(3)
  //   expect(tokensAddr1[2]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[2]["metadataCID"]).to.equal(token3MetadataCID)
  // });

  // it("get tokens owned by any account", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokensAddr1 = await instance.connect(addr2).getTokensOwnedBy(addr1.address)
  //   let tokenOwner = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokenOwner).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(DEFAULT_TOKEN_ID)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(DEFAULT_METADATA_CID)
  //   expect(tokensAddr1[0]["isExist"]).to.be.true
  // });

  // it("get tokens created by me", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokensAddr1 = await instance.connect(addr1).getTokensCreatedByMe()
  //   let tokensAddr2 = await instance.connect(addr2).getTokensCreatedByMe()
  //   let tokenOwner = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokensAddr2).to.be.empty
  //   expect(tokenOwner).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(DEFAULT_TOKEN_ID)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(DEFAULT_METADATA_CID)
  //   expect(tokensAddr1[0]["isExist"]).to.be.true
  // });

  // it("get tokens created by any account", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokensAddr1 = await instance.connect(addr2).getTokensCreatedBy(addr1.address)
  //   let tokenOwner = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokenOwner).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(DEFAULT_TOKEN_ID)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(DEFAULT_METADATA_CID)
  //   expect(tokensAddr1[0]["isExist"]).to.be.true
  // });

  // it("get paginated tokens created by me", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()
  //   let token1MetadataCID = "123456a"
  //   let token2MetadataCID = "123456b"
  //   let token3MetadataCID = "123456c"
  //   let token4MetadataCID = "123456d"
  //   let token5MetadataCID = "123456e"
  //   let token6MetadataCID = "123456f"
  //   let countTokens = 3

  //   await instance.connect(addr1).mintToken(token1MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token2MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token3MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token4MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token5MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token6MetadataCID, DEFAULT_TOKEN_ROYALTY)

  //   let tokensAddr1 = await instance.connect(addr1).getPaginatedTokensCreatedByMe(countTokens)
  //   let tokensAddr2 = await instance.connect(addr2).getPaginatedTokensCreatedByMe(countTokens)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokensAddr1).to.be.length(countTokens)
  //   expect(tokensAddr2).to.be.empty
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(1)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(token1MetadataCID)
  //   expect(tokensAddr1[1]["tokenId"]).to.equal(2)
  //   expect(tokensAddr1[1]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[1]["metadataCID"]).to.equal(token2MetadataCID)
  //   expect(tokensAddr1[2]["tokenId"]).to.equal(3)
  //   expect(tokensAddr1[2]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[2]["metadataCID"]).to.equal(token3MetadataCID)
  // });


  // it("get paginated tokens created by any account", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()
  //   let token1MetadataCID = "123456a"
  //   let token2MetadataCID = "123456b"
  //   let token3MetadataCID = "123456c"
  //   let token4MetadataCID = "123456d"
  //   let token5MetadataCID = "123456e"
  //   let token6MetadataCID = "123456f"
  //   let countTokens = 3

  //   await instance.connect(addr1).mintToken(token1MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token2MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token3MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token4MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token5MetadataCID, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(token6MetadataCID, DEFAULT_TOKEN_ROYALTY)

  //   let tokensAddr1 = await instance.connect(addr2).getPaginatedTokensCreatedBy(addr1.address, countTokens)
  //   let tokensAddr2 = await instance.connect(addr1).getPaginatedTokensCreatedBy(addr2.address, countTokens)

  //   expect(tokensAddr1).not.be.empty
  //   expect(tokensAddr1).to.be.length(countTokens)
  //   expect(tokensAddr2).to.be.empty
  //   expect(tokensAddr1[0]["tokenId"]).to.equal(1)
  //   expect(tokensAddr1[0]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[0]["metadataCID"]).to.equal(token1MetadataCID)
  //   expect(tokensAddr1[1]["tokenId"]).to.equal(2)
  //   expect(tokensAddr1[1]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[1]["metadataCID"]).to.equal(token2MetadataCID)
  //   expect(tokensAddr1[2]["tokenId"]).to.equal(3)
  //   expect(tokensAddr1[2]["creator"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["owner"]).to.equal(addr1.address)
  //   expect(tokensAddr1[2]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokensAddr1[2]["metadataCID"]).to.equal(token3MetadataCID)
  // });

  // it("get token by id", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let token = await instance.connect(addr1).getTokenById(DEFAULT_TOKEN_ID)
  //   let tokenOwner = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(token).not.be.null
  //   expect(tokenOwner).to.equal(addr1.address)
  //   expect(token.royalty).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(token.creator).to.equal(addr1.address)
  //   expect(token.isExist).to.be.true
  // });

  // it("get token by metadata CID", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let token = await instance.connect(addr1).getTokenByMetadataCid(DEFAULT_METADATA_CID)
  //   let tokenOwner = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(token).not.be.null
  //   expect(tokenOwner).to.equal(addr1.address)
  //   expect(token.royalty).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(token.creator).to.equal(addr1.address)
  //   expect(token.isExist).to.be.true
  // });

  // it("get tokens by metadata CID array", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenMetadataCid = "23213dsf"
  //   let secondTokenMetadataCid = "fdsfdsr43243"
  //   let thirdTokenMetadataCid = "43243rewsrewr"
  //   let firstTokenId = 1
  //   let secondTokenId = 2

  //   await instance.connect(addr1).mintToken(firstTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokenList = await instance.connect(addr1).getTokensByMetadataCids([firstTokenMetadataCid, secondTokenMetadataCid])

  //   expect(tokenList).to.be.an('array').that.is.not.empty
  //   expect(tokenList).to.have.length(2)
  //   expect(tokenList[0]["tokenId"]).to.equal(firstTokenId)
  //   expect(tokenList[0]["creator"]).to.equal(addr1.address)
  //   expect(tokenList[0]["owner"]).to.equal(addr1.address)
  //   expect(tokenList[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokenList[0]["metadataCID"]).to.equal(firstTokenMetadataCid)
  //   expect(tokenList[0]["isExist"]).to.be.true
  //   expect(tokenList[1]["tokenId"]).to.equal(secondTokenId)
  //   expect(tokenList[1]["creator"]).to.equal(addr1.address)
  //   expect(tokenList[1]["owner"]).to.equal(addr1.address)
  //   expect(tokenList[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokenList[1]["metadataCID"]).to.equal(secondTokenMetadataCid)
  //   expect(tokenList[1]["isExist"]).to.be.true

  // });

  // it("get tokens by metadata CID array - request unavailable items", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenMetadataCid = "23213dsf"
  //   let secondTokenMetadataCid = "fdsfdsr43243"
  //   let thirdTokenMetadataCid = "43243rewsrewr"
  //   let unavailableTokenMetadataCid = "rewrwe4324324"
  //   let anotherUnavailableTokenMetadataCid = "rew432hfjksdhfk"
  //   let firstTokenId = 1
  //   let secondTokenId = 2

  //   await instance.connect(addr1).mintToken(firstTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokenList = await instance.connect(addr1).getTokensByMetadataCids([firstTokenMetadataCid, secondTokenMetadataCid, unavailableTokenMetadataCid, anotherUnavailableTokenMetadataCid])

  //   expect(tokenList).to.be.an('array').that.is.not.empty
  //   expect(tokenList).to.have.length(2)
  //   expect(tokenList[0]["tokenId"]).to.equal(firstTokenId)
  //   expect(tokenList[0]["creator"]).to.equal(addr1.address)
  //   expect(tokenList[0]["owner"]).to.equal(addr1.address)
  //   expect(tokenList[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokenList[0]["metadataCID"]).to.equal(firstTokenMetadataCid)
  //   expect(tokenList[0]["isExist"]).to.be.true
  //   expect(tokenList[1]["tokenId"]).to.equal(secondTokenId)
  //   expect(tokenList[1]["creator"]).to.equal(addr1.address)
  //   expect(tokenList[1]["owner"]).to.equal(addr1.address)
  //   expect(tokenList[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokenList[1]["metadataCID"]).to.equal(secondTokenMetadataCid)
  //   expect(tokenList[1]["isExist"]).to.be.true

  // });

  // it("get tokens by metadata CID array - No request any item", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenMetadataCid = "23213dsf"
  //   let secondTokenMetadataCid = "fdsfdsr43243"
  //   let thirdTokenMetadataCid = "43243rewsrewr"

  //   await instance.connect(addr1).mintToken(firstTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenMetadataCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokenList = await instance.connect(addr1).getTokensByMetadataCids([])

  //   expect(tokenList).to.be.an('array').that.is.empty
  //   expect(tokenList).to.have.length(0)

  // });

  // it("get tokens", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenCid = DEFAULT_METADATA_CID
  //   let secondTokenCid = "4323423"
  //   let thirdTokenCid = "43145665"
  //   let firstTokenId = 1
  //   let secondTokenId = 2
  //   let thirdTokenId = 3

  //   await instance.connect(addr1).mintToken(firstTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokens = await instance.connect(addr1).getTokens([firstTokenId, secondTokenId, thirdTokenId])

  //   expect(tokens).to.be.an('array').that.is.not.empty
  //   expect(tokens).to.have.length(3)
  //   expect(tokens[0]["tokenId"]).to.equal(firstTokenId)
  //   expect(tokens[0]["creator"]).to.equal(addr1.address)
  //   expect(tokens[0]["owner"]).to.equal(addr1.address)
  //   expect(tokens[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokens[0]["metadataCID"]).to.equal(firstTokenCid)
  //   expect(tokens[0]["isExist"]).to.be.true
  //   expect(tokens[1]["tokenId"]).to.equal(secondTokenId)
  //   expect(tokens[1]["creator"]).to.equal(addr1.address)
  //   expect(tokens[1]["owner"]).to.equal(addr1.address)
  //   expect(tokens[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokens[1]["metadataCID"]).to.equal(secondTokenCid)
  //   expect(tokens[1]["isExist"]).to.be.true
  //   expect(tokens[2]["tokenId"]).to.equal(thirdTokenId)
  //   expect(tokens[2]["creator"]).to.equal(addr1.address)
  //   expect(tokens[2]["owner"]).to.equal(addr1.address)
  //   expect(tokens[2]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokens[2]["metadataCID"]).to.equal(thirdTokenCid)
  //   expect(tokens[2]["isExist"]).to.be.true
  // });

  // it("get tokens - Request some unavailable item", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenCid = DEFAULT_METADATA_CID
  //   let secondTokenCid = "4323423"
  //   let thirdTokenCid = "43145665"
  //   let unavailableTokenId = 5
  //   let anotherUnavailableTokenId = 6
  //   let firstTokenId = 1
  //   let secondTokenId = 2

  //   await instance.connect(addr1).mintToken(firstTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokens = await instance.connect(addr1).getTokens([firstTokenId, secondTokenId, unavailableTokenId, anotherUnavailableTokenId])

  //   expect(tokens).to.be.an('array').that.is.not.empty
  //   expect(tokens).to.have.length(2)
  //   expect(tokens[0]["tokenId"]).to.equal(firstTokenId)
  //   expect(tokens[0]["creator"]).to.equal(addr1.address)
  //   expect(tokens[0]["owner"]).to.equal(addr1.address)
  //   expect(tokens[0]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokens[0]["metadataCID"]).to.equal(firstTokenCid)
  //   expect(tokens[0]["isExist"]).to.be.true
  //   expect(tokens[1]["tokenId"]).to.equal(secondTokenId)
  //   expect(tokens[1]["creator"]).to.equal(addr1.address)
  //   expect(tokens[1]["owner"]).to.equal(addr1.address)
  //   expect(tokens[1]["royalty"]).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokens[1]["metadataCID"]).to.equal(secondTokenCid)
  //   expect(tokens[1]["isExist"]).to.be.true
  // });

  // it("get tokens - request only unavailable items", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenCid = DEFAULT_METADATA_CID
  //   let secondTokenCid = "4323423"
  //   let thirdTokenCid = "43145665"
  //   let unavailableTokenId = 5
  //   let anotherUnavailableTokenId = 6


  //   await instance.connect(addr1).mintToken(firstTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokens = await instance.connect(addr1).getTokens([unavailableTokenId, anotherUnavailableTokenId])

  //   expect(tokens).to.be.an('array').that.is.empty
  //   expect(tokens).to.have.length(0)
  // });

  // it("get tokens - No request any item", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   let firstTokenCid = DEFAULT_METADATA_CID
  //   let secondTokenCid = "4323423"
  //   let thirdTokenCid = "43145665"


  //   await instance.connect(addr1).mintToken(firstTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(secondTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   await instance.connect(addr1).mintToken(thirdTokenCid, DEFAULT_TOKEN_ROYALTY)
  //   let tokens = await instance.connect(addr1).getTokens([])

  //   expect(tokens).to.be.an('array').that.is.empty
  //   expect(tokens).to.have.length(0)
  // });

  // it("transfer token", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokenBeforeTrans = await instance.connect(addr1).getTokenById(DEFAULT_TOKEN_ID)
  //   let tokenOwnerBeforeTrans = await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)
  //   await instance.connect(addr1).transferFrom(addr1.address, addr2.address, DEFAULT_TOKEN_ID);
  //   let tokenAfterTrans = await instance.connect(addr2).getTokenById(DEFAULT_TOKEN_ID)
  //   let tokenOwnerAfterTrans = await instance.connect(addr2).ownerOf(DEFAULT_TOKEN_ID)

  //   expect(tokenBeforeTrans).not.be.null
  //   expect(tokenOwnerBeforeTrans).to.equal(addr1.address)
  //   expect(tokenBeforeTrans.royalty).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokenBeforeTrans.creator).to.equal(addr1.address)
  //   expect(tokenAfterTrans).not.be.null
  //   expect(tokenOwnerAfterTrans).to.equal(addr2.address)
  //   expect(tokenAfterTrans.royalty).to.equal(DEFAULT_TOKEN_ROYALTY)
  //   expect(tokenAfterTrans.creator).to.equal(addr1.address)
  // });

  // it("burn token", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokensOwnedByMeBeforeBurning = await instance.connect(addr1).getTokensOwnedByMe()
  //   await instance.connect(addr1).burn(DEFAULT_TOKEN_ID)
  //   let tokensOwnedByMeAfterBurning = await instance.connect(addr1).getTokensOwnedByMe()

  //   var getTokenByIdErrorMessage: Error | null = null
  //   try {
  //     await instance.connect(addr1).getTokenById(DEFAULT_TOKEN_ID)
  //   } catch (error) {
  //     if (error instanceof Error) {
  //       getTokenByIdErrorMessage = error
  //     }
  //   }

  //   var ownerOfErrorMessage: Error | null = null
  //   try {
  //     await instance.connect(addr1).ownerOf(DEFAULT_TOKEN_ID)
  //   } catch (error) {
  //     if (error instanceof Error) {
  //       ownerOfErrorMessage = error
  //     }
  //   }

  //   expect(tokensOwnedByMeBeforeBurning).not.to.be.empty
  //   expect(tokensOwnedByMeAfterBurning).to.be.empty
  //   expect(getTokenByIdErrorMessage).not.be.null
  //   expect(getTokenByIdErrorMessage!!.message).to.contain("There aren't any token with the token id specified")
  //   expect(ownerOfErrorMessage).not.be.null
  //   expect(ownerOfErrorMessage!!.message).to.contain("ERC721: invalid token ID")
  // });

  // it("pause contract", async function () {
  //   const { instance, addr1 } = await deployContractFixture()

  //   await instance.pause()

  //   var errorMessage: Error | null = null
  //   try {
  //     await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   } catch (error) {
  //     if (error instanceof Error) {
  //       errorMessage = error
  //     }
  //   }

  //   let isPaused = await instance.paused()

  //   expect(isPaused).to.be.true
  //   expect(errorMessage).not.be.null
  //   expect(errorMessage!!.message).to.contain("Pausable: paused")

  // });

  // it("count tokens owned by address", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let countTokensOwnedByAddr1 = await instance.connect(addr1).countTokensOwnedByAddress(addr1.address)
  //   let countTokensOwnedByAddr2 = await instance.connect(addr2).countTokensOwnedByAddress(addr2.address)

  //   expect(countTokensOwnedByAddr1).to.equal(1)
  //   expect(countTokensOwnedByAddr2).to.equal(0)
  // })

  // it("count tokens creator by address", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let countTokensOwnedByAddr1 = await instance.connect(addr1).countTokensCreatorByAddress(addr1.address)
  //   let countTokensOwnedByAddr2 = await instance.connect(addr2).countTokensCreatorByAddress(addr2.address)

  //   expect(countTokensOwnedByAddr1).to.equal(1)
  //   expect(countTokensOwnedByAddr2).to.equal(0)
  // })


  // it("fetch tokens statistics by address", async function () {
  //   const { instance, addr1, addr2 } = await deployContractFixture()

  //   await instance.connect(addr1).mintToken(DEFAULT_METADATA_CID, DEFAULT_TOKEN_ROYALTY)
  //   let tokensStatisticsByAddr1 = await instance.connect(addr1).fetchTokensStatisticsByAddress(addr1.address)
  //   let tokensStatisticsByAddr2 = await instance.connect(addr2).fetchTokensStatisticsByAddress(addr2.address)

  //   expect(tokensStatisticsByAddr1.countTokensCreator).to.equal(1)
  //   expect(tokensStatisticsByAddr1.countTokensOwned).to.equal(1)
  //   expect(tokensStatisticsByAddr2.countTokensCreator).to.equal(0)
  //   expect(tokensStatisticsByAddr2.countTokensOwned).to.equal(0)
  // })
});
