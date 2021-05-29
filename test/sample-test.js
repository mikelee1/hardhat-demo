const { expect } = require("chai");

describe("Greeter", function () {
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

describe("Home", function () {
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
    await home.createUser("mike", "i am mike, hello!", 18);

    // expect(await greeter.connect(addr2).getInvoker()).to.equal(addr2.address);
  });

  it("update user", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let name = "mike";
    let oldProfile = "i am mike, hello!";
    let newProfile = "i am 666, hello!";
    await home.createUser(name, oldProfile, 18);
    expect(await home.queryMyProfile()).to.equal(oldProfile);

    await home.updateProfile(newProfile);
    expect(await home.queryMyName()).to.equal(name);
    expect(await home.queryMyProfile()).to.equal(newProfile);
  });
});
