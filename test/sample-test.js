const { expect } = require("chai");

describe("Mainnet contract", function () {
  it("test uni token", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const MyContract = await ethers.getContractFactory("Uni");
    const contract = await MyContract.deploy(
      "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984" // The deployed mainnet contract address
    );
    await contract.deployed();

    // Now you can call functions of the contract
    expect((await contract.totalSupply()).toString()).to.equal(
      "1000000000000000000000000000"
    );
    expect(await contract.name()).to.equal("Uniswap");
    expect(await contract.symbol()).to.equal("UNI");
    expect(await contract.minter()).to.equal(
      "0x1a9C8182C09F50C8318d769245beA52c32BE35BC"
    );
  });
});

describe("GreeterContract", function () {
  let greeter;
  beforeEach(async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();
  });

  it("Should return the new greeting once it's changed", async function () {
    expect(await greeter.greet()).to.equal("Hello, world!");
    await greeter.setGreeting("Hola, mundo!");
    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });

  it("Should return the correct invoker", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    expect(await greeter.getInvoker()).to.equal(owner.address);
    expect(await greeter.connect(addr1).getInvoker()).to.equal(addr1.address);
    expect(await greeter.connect(addr2).getInvoker()).to.equal(addr2.address);
  });
});

describe("HomeContract", function () {
  let greeter;
  let home;
  beforeEach(async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();

    const Home = await ethers.getContractFactory("Home");
    home = await Home.deploy(greeter.address);
    await home.deployed();
  });

  it("add user", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await home.createUser(owner.address, "mike", "i am mike, hello!", 18);
    let result = await home.queryMyInfo();
    expect(result[0]).to.equal("mike");
  });

  it("add exist user", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await home.createUser(owner.address, "mike", "i am mike, hello!", 18);
    await expect(
      home.createUser(owner.address, "mike", "i am mike, hello!", 18)
    ).to.be.revertedWith("user is exist");
  });

  it("invoke is valid", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await expect(
      home.connect(addr1).updateProfile("i am mike, hello!")
    ).to.be.revertedWith("user is invalid");
  });

  it("fail to create user", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    await expect(
      home
        .connect(addr1)
        .createUser(addr1.address, "addr1", "i am addr1, hello!", 28)
    ).to.be.revertedWith("need admin");
  });

  it("update user profile", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let name = "mike";
    let oldProfile = "i am mike, hello!";
    let newProfile = "i am 666, hello!";

    await home.createUser(owner.address, name, oldProfile, 18);
    await home.createUser(addr1.address, "addr1", "i am addr1, hello!", 28);

    let result = await home.queryMyInfo();
    expect(result[1]).to.equal(oldProfile);

    await home.updateProfile(newProfile);
    result = await home.queryMyInfo();
    expect(result[0]).to.equal(name);
    expect(result[1]).to.equal(newProfile);

    await home.connect(addr1).updateProfile(newProfile);
    result = await home.connect(addr1).queryMyInfo();
    expect(result[0]).to.equal("addr1");
    expect(result[1]).to.equal(newProfile);
  });
});

describe("TradeContract", function () {
  let greeter;
  let home;
  beforeEach(async function () {
    const TradeContract = await ethers.getContractFactory("TradeContract");
    tradeContract = await TradeContract.deploy(1, 100);
    await tradeContract.deployed();
  });

  it("add trade", async function () {
    let _value = 1;
    let _tradeId = 0;
    const [owner, addr1, addr2] = await ethers.getSigners();
    await tradeContract.createTrade(_value, { value: _value });
    let result = await tradeContract.queryTrade(_tradeId);
    expect(result[0]).to.equal(owner.address);
    expect(result[2].toNumber()).to.equal(_value);
  });

  it("invalid tradeId", async function () {
    await expect(tradeContract.queryTrade(1)).to.be.revertedWith(
      "invalid tradeId"
    );
  });

  it("deposit trade", async function () {
    let _value = 1;
    let _tradeId = 0;
    const [owner, addr1, addr2] = await ethers.getSigners();
    await tradeContract.createTrade(_value, { value: _value });
    await tradeContract
      .connect(addr1)
      .depositTrade(_tradeId, { value: _value });
  });

  it("buy trade", async function () {
    let _value = 1;
    let _tradeId = 0;
    const [owner, addr1, addr2] = await ethers.getSigners();
    await tradeContract.createTrade(_value, { value: _value });
    await tradeContract
      .connect(addr1)
      .depositTrade(_tradeId, { value: _value });
    await tradeContract.connect(addr1).buyTrade(_tradeId, { value: _value });
  });

  it("withdraw", async function () {
    let _value = 1;
    let _tradeId = 0;
    const [owner, addr1, addr2] = await ethers.getSigners();
    await tradeContract.createTrade(_value, { value: _value });
    await tradeContract
      .connect(addr1)
      .depositTrade(_tradeId, { value: _value });
    await tradeContract.connect(addr1).buyTrade(_tradeId, { value: _value });

    await expect(
      tradeContract.connect(owner).withdraw(_tradeId)
    ).to.be.revertedWith("invalid withdraw order");

    await expect(tradeContract.connect(addr1).withdraw(_tradeId))
      .to.emit(tradeContract, "WithdrawEvent")
      .withArgs(_tradeId, addr1.address);

    await expect(tradeContract.connect(owner).withdraw(_tradeId))
      .to.emit(tradeContract, "WithdrawEvent")
      .withArgs(_tradeId, owner.address);
  });
});

describe("TokenContract", function () {
  let token;
  beforeEach(async function () {
    const Token = await ethers.getContractFactory("TokenContract");
    token = await Token.deploy("LT", "Lee token", 10000000);
    await token.deployed();
  });

  it("info", async function () {
    expect(await token.name()).to.equal("LT");
    expect(await token.symbol()).to.equal("Lee token");
    expect(await token.decimals()).to.equal(18);
  });

  it("transfer", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let formerBalance = (await token.balanceOf(owner.address)).toNumber();
    await token.transfer(addr1.address, 10);
    expect((await token.balanceOf(owner.address)).toNumber()).to.equal(
      formerBalance - 10
    );
  });

  it("mint", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let formerBalance = (await token.balanceOf(owner.address)).toNumber();
    let _amount = 10;
    await expect(token.connect(addr1).mint(owner.address, 10)).to.revertedWith(
      "must admin"
    );

    await expect(token.mint(owner.address, _amount))
      .to.emit(token, "Mint")
      .withArgs(owner.address, _amount);
    expect((await token.balanceOf(owner.address)).toNumber()).to.equal(
      formerBalance + _amount
    );
  });
});
