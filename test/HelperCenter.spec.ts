import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";

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
    await helperCenter.initialize(testGateway.address);
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
    token = await Token.connect(accounts[0]).deploy(100000000);
    helperCenter = await HelperCenter.deploy();
    testGateway = await TestGateway.deploy();
    helperUnit = await HelperUnit.deploy();
    await setInit();
  })

  it("should emit HelperLogicAdded when add helper", async function () {
    helperId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MyNFT:buyItem()"))
    expect(await helperCenter.addHelperLogic(helperId, helperUnit.address)).to.emit(helperCenter, "HelperLogicAdded");
  })

  it("should revert when add the same helper", async function () {
    helperId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MyNFT:buyItem()"))
    await expect(helperCenter.addHelperLogic(helperId, helperUnit.address)).to.be.revertedWith('This helper already added');
  })

  it("create tx", async function () {   
    await token.connect(accounts[0]).transfer(testGateway.address, 10000);
    let calldata = setCallData(helperId);
    await testGateway.execute(helperCenter.address, calldata);
  });
});

