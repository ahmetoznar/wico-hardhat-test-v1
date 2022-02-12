const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Brand", function () {
  let brand, token;
  it("Deployed", async function () {
    const Brand = await ethers.getContractFactory("Brand");
    const Token = await ethers.getContractFactory("Token");
    const accounts = await ethers.getSigners();
    brand = await Brand.deploy();
    await brand.deployed();
    token = await Token.deploy();
    await token.deployed();
    await token.transfer(accounts[1].address, String(50 * 1e18));
    await token.transfer(accounts[2].address, String(10 * 1e18));
    await token.transfer(accounts[3].address, String(10 * 1e18));
    await token.transfer(accounts[4].address, String(10 * 1e18));

    expect(await brand.deployed());
  });
  it("Setted contract settings", async function () {
    const [owner, addr1] = await ethers.getSigners();
    const baseURI = "https://brandNFT.io/";
    const settingsTx = await brand.setSettings(
      owner.address,
      5,
      Math.floor(Date.now() / 1000),
      Math.floor(Date.now() / 1000 + 3600),
      Math.floor(Date.now() / 1000),
      Math.floor(Date.now() / 1000 + 3500),
      token.address
    );

    const baseURISetTX = await brand.setBaseURI(baseURI);
    await baseURISetTX.wait();

    expect(await brand.STABLE_TOKEN()).to.equal(token.address);
  });

  it("Set category details", async function () {
    await brand.setCategory(0, String(1e18));
    await brand.setCategory(1, String(2 * 1e18));
    await brand.setCategory(2, String(3 * 1e18));
    await brand.setCategory(3, String(4 * 1e18));
    const settingsTx = await brand.setCategory(4, String(5 * 1e18));
    await settingsTx.wait();
    expect(await brand._getMintPrice(4)).to.equal(String(5 * 1e18));
  });

  it("Set merkle root", async function () {
    const settingsTx = await brand.setMerkleRoot(
      "46982731997293706193088736743098830284845527797516881022688416749593684446208"
    );
    await settingsTx.wait();
    const merkleRoot = await brand.getMerkleRoot();
    expect(merkleRoot).to.equal(
      "46982731997293706193088736743098830284845527797516881022688416749593684446208"
    );
  });

  it("Deposit #1", async function () {
    const accounts = await ethers.getSigners();
    await token
      .connect(accounts[0])
      .approve(brand.address, BigInt(3000000000000000000));
    await brand.connect(accounts[0]).deposit(2);
    const balance = await token.balanceOf(brand.address);
    expect(balance).to.equal(String(3 * 1e18));
  });

  it("Deposit #2", async function () {
    const accounts = await ethers.getSigners();
    await token
      .connect(accounts[0])
      .approve(brand.address, BigInt(2000000000000000000));
    await brand.connect(accounts[0]).deposit(1);
    const balance = await token.balanceOf(brand.address);
    expect(balance).to.equal(String(5 * 1e18));
  });

  it("Verify Merkle Proof #1", async function () {
    const leaf = await brand.getLeaf(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      ["3250262626", "5342674263"]
    );
    const verify = await brand.verifyMerkle(leaf, [
      "68545430841861028347070627093890374864491243377544895656371962925176237347127",
      "95308519830355275807576965213401907173159893607468842106712690456577094131782",
    ]);
    expect(verify).to.ok;
  });

  it("set exclusive user", async function () {
    const accounts = await ethers.getSigners();
    const setExclusive = await brand
      .connect(accounts[0])
      .setExclude(accounts[4].address, true, 25);
    await setExclusive.wait();
    expect(await brand.isTokenSoldByBrand(25)).to.equal(true);
  });

  it("is exclusive user setted", async function () {
    const accounts = await ethers.getSigners();
    const tokenId = await brand.excludeFromFeeID(accounts[4].address);
    expect(tokenId).to.equals(25);
  });

  it("Mint for exlusive user", async function () {
    const accounts = await ethers.getSigners();
    const mintTx = await brand
      .connect(accounts[4])
      .mint(
        40,
        ["3250262626", "5342674263"],
        [
          "68545430841861028347070627093890374864491243377544895656371962925176237347127",
          "95308519830355275807576965213401907173159893607468842106712690456577094131782",
        ]
      );
    await mintTx.wait();
    const ownerOfNFT = await brand.ownerOf(25);
    expect(ownerOfNFT).to.equal(accounts[4].address);
  });

  it("deposit bronze #1", async function () {
    const accounts = await ethers.getSigners();
    await token
      .connect(accounts[0])
      .approve(brand.address, BigInt(10000000000000000000));
    await brand.connect(accounts[0]).deposit(4);
    const balance = await token.balanceOf(brand.address);
    expect(balance).to.equal(String(10 * 1e18));
  });

  it("deposit bronze #2", async function () {
    const accounts = await ethers.getSigners();
    await token
      .connect(accounts[0])
      .approve(brand.address, BigInt(10000000000000000000));
    await brand.connect(accounts[0]).deposit(4);
    const balance = await token.balanceOf(brand.address);
    expect(balance).to.equal(String(15 * 1e18));
  });

  it("Mint Bronze #1", async function () {
    const accounts = await ethers.getSigners();
    const sendMint = await brand
      .connect(accounts[0])
      .mint(
        160,
        ["3250262626", "5342674263"],
        [
          "68545430841861028347070627093890374864491243377544895656371962925176237347127",
          "95308519830355275807576965213401907173159893607468842106712690456577094131782",
        ]
      );
    await sendMint.wait();
    const ownerOfNFT = await brand.ownerOf(160);
    expect(ownerOfNFT).to.equal(accounts[0].address);
  });

  it("Withdraw #1", async function () {
    const accounts = await ethers.getSigners();
    const sendWithdraw = await brand.connect(accounts[0]).withdraw();
    await sendWithdraw.wait();
    const userData = await brand.getUserData(accounts[0].address);
    expect(userData.isWithdraw).to.equal(true);
  });

  it("Mint Bronze #2", async function () {
    const accounts = await ethers.getSigners();
    try {
      const sendMint = await brand
        .connect(accounts[0])
        .mint(
          167,
          ["3250262626", "5342674263"],
          [
            "68545430841861028347070627093890374864491243377544895656371962925176237347127",
            "95308519830355275807576965213401907173159893607468842106712690456577094131782",
          ]
        );
      await sendMint.wait();
    } catch (error) {}
  });
});
//done
