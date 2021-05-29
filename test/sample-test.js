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
