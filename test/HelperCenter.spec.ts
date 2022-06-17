import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades  } from "hardhat";


describe("HelperCenter", function () {
  let nft: Contract;
  let token: Contract;
  let helperCenter: Contract;
  let testGateway: Contract;
  let helperUnit: Contract;
  let accounts: SignerWithAddress[];
  let helperId: string;

  async function setInit() {
    await nft.setToken(token.address);
    await testGateway.setToken(token.address);
    await helperUnit.setHelperCenter(helperCenter.address);
  }



  function setCallData(helperId: string): string{
    let abiCoder = new ethers.utils.AbiCoder();
    let selector =  ethers.utils.hexDataSlice(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buyItem()")),0,4);
    return abiCoder.encode(["bytes32","bytes4", "address", "address", "address", "bytes"],[helperId, selector, token.address, nft.address, accounts[3].address, "0x"]);
  }

  before(async function() {
    accounts = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("NFTItem");
    const Token = await ethers.getContractFactory("Token");
    const HelperCenter = await ethers.getContractFactory("HelperCenter");
    const HelperUnit = await ethers.getContractFactory("NFTMintUnit");
    const TestGateway = await ethers.getContractFactory("TestCenterGateway");
    nft = await NFT.deploy();
    token = await Token.connect(accounts[0]).deploy(ethers.utils.parseEther("100"));
    testGateway = await TestGateway.deploy();
    helperCenter = await upgrades.deployProxy(HelperCenter,[testGateway.address, false]);
    helperUnit = await HelperUnit.deploy();
    await setInit();
    await token.connect(accounts[0]).transfer(testGateway.address, ethers.utils.parseEther("10"));
  })

  it("should revert if not owner", async function () {
    helperId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MyNFT:buyItem()"))
    await expect(helperCenter.connect(accounts[1]).addHelperLogic(helperId, helperUnit.address)).to.be.revertedWith('Ownable: caller is not the owner');
  })

  it("should emit HelperLogicAdded when add helper", async function () {
    helperId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MyNFT:buyItem()"))
    expect(await helperCenter.connect(accounts[0]).addHelperLogic(helperId, helperUnit.address)).to.emit(helperCenter, "HelperLogicAdded");
  })

  it("should revert when call to changeTransferBackSetting while not the owner", async function () {
    await expect(helperCenter.connect(accounts[1]).changeTransferBackSetting(false)).to.be.revertedWith("Ownable: caller is not the owner");
  })

  it("should revert when call to changeTransferBackSetting with the same setting", async function () {
    await expect(helperCenter.connect(accounts[0]).changeTransferBackSetting(false)).to.be.revertedWith("Already set to the traget boolean value");
  })

  it("should emit ShouldTransferBackChanged when call to changeTransferBackSetting with right config", async function () {
    await expect(helperCenter.connect(accounts[0]).changeTransferBackSetting(true)).to.emit(helperCenter,"ShouldTransferBackChanged");
  })

  it("should revert when add the same helper", async function () {
    helperId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MyNFT:buyItem()"))
    await expect(helperCenter.addHelperLogic(helperId, helperUnit.address)).to.be.revertedWith('This helper already added');
  })

  it("create tx", async function () {   
    let calldata = setCallData(helperId);
    expect(await testGateway.execute(helperCenter.address, calldata, ethers.utils.parseEther("1"))).to.emit(testGateway, "ExecuteSuccess");
  });

  it("should get the surplus token back when shouldTransferBack is true", async function () {
    let calldata = setCallData(helperId);
    let beforeBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    expect(await testGateway.execute(helperCenter.address, calldata, ethers.utils.parseEther("2"))).to.emit(testGateway, "ExecuteSuccess");
    let afterBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    expect(afterBalance.sub(beforeBalance)).equal(ethers.utils.parseEther("1"));
  })

  it("should not get the surplus token back when shouldTransferBack is false", async function () {
    await expect(helperCenter.connect(accounts[0]).changeTransferBackSetting(false)).to.emit(helperCenter,"ShouldTransferBackChanged");
    const calldata = setCallData(helperId);
    const beforeBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    const contractBeforeBalance = ethers.BigNumber.from(await token.balanceOf(helperCenter.address));
    expect(await testGateway.execute(helperCenter.address, calldata, ethers.utils.parseEther("2"))).to.emit(testGateway, "ExecuteSuccess");
    const afterBalance = ethers.BigNumber.from(await token.balanceOf(accounts[3].address));
    const contractAfterBalance = ethers.BigNumber.from(await token.balanceOf(helperCenter.address));
    expect(afterBalance).equal(beforeBalance);
    expect(contractAfterBalance).gt(contractBeforeBalance);
  })
});

