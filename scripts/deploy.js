// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const uniV3Pool = "0x4e68ccd3e89f51c3074ca5072bbac773960dfa36";
async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await run("compile");

  const [deployer] = await ethers.getSigners();
  deployerAddress = await deployer.getAddress();
  console.log("Deploying contracts with the account:", deployerAddress);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const Greeter = await ethers.getContractFactory("Greeter");
  const greeter = await Greeter.deploy("Hello, Hardhat!");
  await greeter.deployed();

  const Home = await ethers.getContractFactory("Home");
  const home = await Home.deploy(greeter.address);
  await home.deployed();

  const _protocolFee = "50000";
  const _maxTotalSupply = 100000000000000000000n;
  const Vault = await ethers.getContractFactory("AlphaVault");
  const vault = await Vault.deploy(uniV3Pool, _protocolFee, _maxTotalSupply);
  await vault.deployed();

  // const _baseThreshold = 3600;
  // const _limitThreshold = 1200;
  // const _maxTwapDeviation = 100;
  // const _twapDuration = 60;
  // const _keeper = deployerAddress;
  // const Strategy = await ethers.getContractFactory("AlphaStrategy");
  // const strategy = await Strategy.deploy(
  //   vault.address,
  //   _baseThreshold,
  //   _limitThreshold,
  //   _maxTwapDeviation,
  //   _twapDuration,
  //   _keeper
  // );
  // console.log("Strategy deployed to:", strategy.address);
  // await vault.deployed();
  // console.log("Vault deployed to:", vault.address);

  console.log("Greeter deployed to:", greeter.address);
  console.log("Home deployed to:", home.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
