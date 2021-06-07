// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

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

  const Vault = await ethers.getContractFactory("AlphaVault");
  const vault = await Vault.deploy(
    "0x4e68ccd3e89f51c3074ca5072bbac773960dfa36",
    "50000",
    100000000000000000000n
  );
  await vault.deployed();

  const Strategy = await ethers.getContractFactory("AlphaStrategy");
  const strategy = await Strategy.deploy(
    vault.address,
    3600,
    1200,
    100,
    60,
    deployerAddress
  );
  await vault.deployed();

  console.log("Greeter deployed to:", greeter.address);
  console.log("Home deployed to:", home.address);
  console.log("Vault deployed to:", vault.address);
  console.log("Strategy deployed to:", strategy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
