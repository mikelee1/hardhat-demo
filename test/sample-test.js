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
    await home.createUser(owner.address, "mike", "i am mike, hello!", 18);

    // expect(await greeter.connect(addr2).getInvoker()).to.equal(addr2.address);
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
