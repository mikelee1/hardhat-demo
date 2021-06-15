const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");

describe("Alpha vault and Strategy contract", function () {
  const uniV3Pool = "0x4e68ccd3e89f51c3074ca5072bbac773960dfa36"; //mike 这个是v3
  const uniV2Pool = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; //mike 这里实际用的是v2
  let vault;
  let strategy;
  let uniswapPool;

  const _baseThreshold = 3600;
  const _limitThreshold = 1200;
  const _maxTwapDeviation = 100;
  const _twapDuration = 60;

  const _protocolFee = "50000";
  const _maxTotalSupply = 100000000000000000000n;

  const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  const factory = "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f";
  const _tickSpacing = 60;

  beforeEach(async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    //mike 部署vault
    const Vault = await ethers.getContractFactory("AlphaVault");
    vault = await Vault.deploy(uniV3Pool, _protocolFee, _maxTotalSupply);
    await vault.deployed();
    //mike 部署strategy
    const Strategy = await ethers.getContractFactory("AlphaStrategy");
    strategy = await Strategy.deploy(
      vault.address,
      _baseThreshold,
      _limitThreshold,
      _maxTwapDeviation,
      _twapDuration,
      owner.address
    );
    await strategy.deployed();

    //mike 部署uniswap
    const UniswapPool = await ethers.getContractFactory("UniswapPool");
    uniswapPool = await UniswapPool.deploy(
      uniV2Pool // The deployed mainnet contract address
    );
    await uniswapPool.deployed();
  });

  it("test uniswapPool", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    // Now you can call functions of the contract
    expect(await uniswapPool.getFactory()).to.equal(
      "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    );
    var weth = await uniswapPool.getWETH();
    await uniswapPool
      .connect(owner)
      .swapExactETHForTokens(0, [weth, usdt], owner.address, 100000000000, {
        value: 100000000000000000000n,
      });
    //todo approve usdt

    // await uniswapPool
    //   .connect(owner)
    //   .swapExactTokensForETH(
    //     127920102035,
    //     0,
    //     [usdt, weth],
    //     owner.address,
    //     100000000000
    //   );
  });

  it("test vault basicinfo", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    // Now you can call functions of the contract
    expect(await vault.token0()).to.equal(weth);
    expect(await vault.token1()).to.equal(usdt);
    expect(await vault.protocolFee()).to.equal(_protocolFee);
    expect(await vault.maxTotalSupply()).to.equal(_maxTotalSupply);
    expect(await vault.tickSpacing()).to.equal(_tickSpacing);
  });

  it("test strategy basicinfo", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    // Now you can call functions of the contract
    expect(await strategy.baseThreshold()).to.equal(_baseThreshold);
    expect(await strategy.limitThreshold()).to.equal(_limitThreshold);
    expect(await strategy.maxTwapDeviation()).to.equal(_maxTwapDeviation);
  });

  it("test vault", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    // Now you can call functions of the contract
    console.log((await owner.getBalance()).toString());
    expect(await vault.accruedProtocolFees0()).to.equal(0);
    console.log((await vault.myBalance0()).toNumber());
    console.log(await vault.myBalance1());
    await expect(
      vault.connect(owner).deposit(100, 100, 0, 0, owner.address)
    ).to.emit(vault, "Deposit");
  });
});

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

describe("NftContract", function () {
  let nft;
  beforeEach(async function () {
    const Nft = await ethers.getContractFactory("NftContract");
    nft = await Nft.deploy("LN", "Lee Nft");
    await nft.deployed();
  });

  it("info", async function () {
    expect(await nft.name()).to.equal("LN");
    expect(await nft.symbol()).to.equal("Lee Nft");
  });

  it("mint to addr1, then transfer to addr2", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let ipfsUrl =
      "ipfs://https://gateway.pinata.cloud/ipfs/QmVSJL4RuDdCqXyG2FfvYbY6CPVQKyNmEyDDjSfe7pXap2/";
    let tokenId = 1; //start from 1
    await expect(nft.mint(addr1.address, "test", ipfsUrl))
      .to.emit(nft, "Mint")
      .withArgs(addr1.address, "test", ipfsUrl);
    await expect(nft.mint(addr1.address, "test", ipfsUrl)).to.be.revertedWith(
      "hash already exist"
    );
    expect(await nft.totalSupply()).to.equal(1);
    expect(await nft.balanceOf(addr2.address)).to.equal(0);
    expect(await nft.balanceOf(addr1.address)).to.equal(1);
    expect(await nft.tokenURI(tokenId)).to.equal(ipfsUrl);
    expect(await nft.ownerOf(tokenId)).to.equal(addr1.address);

    await expect(
      nft.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId)
    )
      .to.emit(nft, "Transfer")
      .withArgs(addr1.address, addr2.address, tokenId);
  });
});

describe("LotteryContract", function () {
  let lottery;
  beforeEach(async function () {
    const Lottery = await ethers.getContractFactory("LotteryContract");
    lottery = await Lottery.deploy();
    await lottery.deployed();
  });

  it("enter game", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await expect(lottery.enterGame({ value: 1 }))
      .to.emit(lottery, "enterGameEvent")
      .withArgs(owner.address);
  });

  it("start game", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await lottery.enterGame({ value: 1 });
    await lottery.connect(addr1).enterGame({ value: 1 });
    await lottery.connect(addr2).enterGame({ value: 1 });
    await expect(lottery.startGame()).to.emit(lottery, "startGameEvent");
  });
});
