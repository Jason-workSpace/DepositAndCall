import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades  } from "hardhat";

describe("HelperSingle", function () {
  let nft: Contract;
  let token: Contract;
  let helper: Contract;
  let testGateway: Contract;
  let accounts: SignerWithAddress[];

  async function setInit() {
    await nft.setToken(token.address);
    await testGateway.setToken(token.address);
  }

  function setCallData(
    selector: string,
    targetAddress: string,
    receiver: string,
    data: string
  ): string{
    let abiCoder = new ethers.utils.AbiCoder();
    
    return abiCoder.encode(["bytes4", "address", "address", "bytes"],[selector, targetAddress, receiver, data]);
  }

  before(async function() {
    accounts = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("NFTItem");
    const Token = await ethers.getContractFactory("Token");
    const Helper = await ethers.getContractFactory("NFTMintHelper");
    const TestGateway = await ethers.getContractFactory("TestGateway");
    nft = await NFT.deploy();
    token = await Token.connect(accounts[0]).deploy(ethers.utils.parseEther("100"));
    testGateway = await TestGateway.deploy();
    helper = await upgrades.deployProxy(Helper,[testGateway.address, nft.address, false]);
    await setInit();
    await token.connect(accounts[0]).transfer(testGateway.address, ethers.utils.parseEther("10"));
  })

  it("should revert when call to changeTransferBackSetting while not the owner", async function () {
    await expect(helper.connect(accounts[1]).changeTransferBackSetting(false)).to.be.revertedWith("Ownable: caller is not the owner");
  })

  it("should revert when call to changeTransferBackSetting with the same setting", async function () {
    await expect(helper.connect(accounts[0]).changeTransferBackSetting(false)).to.be.revertedWith("Already set to the traget boolean value");
  })

  it("should emit ShouldTransferBackChanged when call to changeTransferBackSetting with right config", async function () {
    await expect(helper.connect(accounts[0]).changeTransferBackSetting(true)).to.emit(helper,"ShouldTransferBackChanged");
  })

  it("should revert when not the right function name encode", async function () {
    let selector = ethers.utils.hexDataSlice(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buyMyItem()")),0,4);
    let calldata = setCallData(selector, nft.address, accounts[3].address, "0x");
    await expect(testGateway.execute(helper.address, calldata, ethers.utils.parseEther("1"))).to.be.revertedWith("Not find the related call id");
  }) 

  it("create tx", async function () {
    let selector = ethers.utils.hexDataSlice(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buyItem()")),0,4);
    let calldata = setCallData(selector, nft.address, accounts[3].address, "0x");
    expect(await testGateway.execute(helper.address, calldata, ethers.utils.parseEther("1"))).to.emit(helper, "ExecuteSuccess");
  });

  it("should get the surplus token back when shouldTransferBack is true", async function () {
    let selector = ethers.utils.hexDataSlice(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buyItem()")),0,4);
    let calldata = setCallData(selector, nft.address, accounts[3].address, "0x");
    let beforeBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    expect(await testGateway.execute(helper.address, calldata, ethers.utils.parseEther("2"))).to.emit(testGateway, "ExecuteSuccess");
    let afterBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    expect(afterBalance.sub(beforeBalance)).equal(ethers.utils.parseEther("1"));
  })

  it("should not get the surplus token back when shouldTransferBack is false", async function () {
    let selector = ethers.utils.hexDataSlice(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buyItem()")),0,4);
    await expect(helper.connect(accounts[0]).changeTransferBackSetting(false)).to.emit(helper,"ShouldTransferBackChanged");
    const calldata = setCallData(selector, nft.address, accounts[3].address, "0x");
    const beforeBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    const contractBeforeBalance = ethers.BigNumber.from(await token.balanceOf(helper.address));
    expect(await testGateway.execute(helper.address, calldata, ethers.utils.parseEther("2"))).to.emit(testGateway, "ExecuteSuccess");
    const afterBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    const contractAfterBalance = ethers.BigNumber.from(await token.balanceOf(helper.address));
    expect(afterBalance).equal(beforeBalance);
    
    expect(contractAfterBalance).gt(contractBeforeBalance);
  })
});
