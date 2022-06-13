import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";

describe("HelperSingle", function () {
  let nft: Contract;
  let token: Contract;
  let helper: Contract;
  let testGateway: Contract;
  let accounts: SignerWithAddress[];

  async function setInit() {
    await nft.setToken(token.address);
    await helper.initialize(testGateway.address, nft.address);
    await testGateway.setToken(token.address);
  }

  function setCallData(): string{
    let abiCoder = new ethers.utils.AbiCoder();
    let selector =  ethers.utils.hexDataSlice(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buyItem()")),0,4);
    return abiCoder.encode(["bytes4", "address", "address", "address", "bytes"],[selector, token.address, nft.address, accounts[3].address, "0x"]);
  }

  before(async function() {
    accounts = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("NFTItem");
    const Token = await ethers.getContractFactory("Token");
    const Helper = await ethers.getContractFactory("NFTMintHelper");
    const TestGateway = await ethers.getContractFactory("TestGateway");
    nft = await NFT.deploy();
    token = await Token.connect(accounts[0]).deploy(100000000);
    helper = await Helper.deploy();
    testGateway = await TestGateway.deploy();
    
  })

  it("create tx", async function () {
    await setInit();
    await token.connect(accounts[0]).transfer(testGateway.address, 10000);
    let calldata = setCallData();
    await testGateway.execute(helper.address, calldata);
  });
});
