const { expect } = require("chai");

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
    const [owner, addr1, addr2] = await ethers.getSigners();
    await tradeContract.createTrade(1, { value: 2 });
    let result = await tradeContract.queryTrade(0);
    expect(result[0]).to.equal(owner.address);
    expect(result[2].toNumber()).to.equal(1);
  });
});
