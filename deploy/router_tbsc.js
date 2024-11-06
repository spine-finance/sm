// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.

require("dotenv").config();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
// const hre = require("hardhat");
const ethers = require("ethers");
// const bondData = require("../artifacts/contracts/tokens/BondToken.sol/BondToken.json");
const tokenData = require("../artifacts/contracts/mock/ERC20.sol/MockToken.json");
const bondMMRouterData = require("../artifacts/contracts/Router.sol/Router.json");
// const bondMMData = require("../artifacts/contracts/BondMM.sol/BondMM.json");
const bondMMFactoryData = require("../artifacts/contracts/factories/BondMMFactory.sol/BondMMFactory.json");
const bondFactoryData = require("../artifacts/contracts/factories/BondFactory.sol/BondFactory.json");
// const mockOracleData = require("../artifacts/contracts/mock/MockStablecoinOracle.sol");
const addressZero = "0x0000000000000000000000000000000000000000";
const r0 = 0.02;
const k0 = 0.1;
const vaultAddress = "0x46037fb19526bCe3BAbEF30D03242e8ED68c1b77";
const collateralVaultFactoryData = require("../artifacts/contracts/factories/CollateralVaultFactory.sol/CollateralVaultFactory.json");

// const priceFeeds = {
//   ETH: "0xae7c2c295e3e600269036e68fceb5f6eae0c7e53",
//   BTC: "0x58414bdbeb3de68f066598cd755be1b6e991aa08",
//   UNI: "0x1b3254d1e605d2d045238b2ea24011e91efd5fe4",
//   LINK: "0xe6d673218adeb5d4445f060c250bff84724cb8d0",
//   USDC: "0x8980e60fb3158271bcca7c0b7d6a7259a2885541",
// };

// const tokens = {
//   WETH: "0xca5b8be68ad7c298b2eaa8f6b25d05721d151648",
//   WBTC: "0x115956a99104994bce0a854c320ea090624ae823",
//   UNI: "0xe246b12b6f197057b3a24a62cbc729c67bfbddb4",
//   LINK: "0xCbB15E7eA0Eab2854273C066512a99b66B280535",
//   USDC: "0x037d14d75F2dABc169a2E8Bf0FC36d690Df5980B",
// };

const tokens = {
  BSC: {
    WBNB: {
      address: "0x1857a3f231FBa999084983b66519E520708AD8E2",
      priceFeed: "0x218A5c5fd1DC167f186cFb05Dc88ABd0B01A0C90",
    },
    WETH: {
      address: "0x8E3aDbBF79C4f3cd85d4dEC24cC1eA7CcfCDE139",
      priceFeed: "0xFD00cd69fE5F8FA70178859DE47b9887bA8490f3",
    },
    BTCB: {
      address: "0x1f754B14C327E182b64dac4b7B30dce6E1A5Dab3",
      priceFeed: "0xe246B12B6f197057b3a24a62cBc729C67bfbDdb4",
    },
    slisBNB: {
      address: "0x886e060058D9D4Cb5588Be0f603ca7eb849e5824",
      priceFeed: "0xCbB15E7eA0Eab2854273C066512a99b66B280535",
    },
    USDT: {
      address: "0x9721967546715D78638239A9991F5D5ae50DD95d",
      priceFeed: "0x037d14d75F2dABc169a2E8Bf0FC36d690Df5980B",
    },
    CAKE: {
      address: "0x115956a99104994BCE0A854C320eA090624Ae823",
      priceFeed: "0xA5a735d777cA6D583a8312E40B18F6d896CD0345",
    },
  },
};

async function main() {
  const rpc = "https://data-seed-prebsc-1-s1.bnbchain.org:8545";
  const provider = new ethers.JsonRpcProvider(rpc);
  const privateKey = process.env.PRIVATE_KEY;
  const wallet = new ethers.Wallet(privateKey, provider);
  const BondMMRouter = new ethers.ContractFactory(
    bondMMRouterData.abi,
    bondMMRouterData.bytecode,
    wallet
  );

  const BondFactory = new ethers.ContractFactory(
    bondFactoryData.abi,
    bondFactoryData.bytecode,
    wallet
  );

  const CollateralVaultFactory = new ethers.ContractFactory(
    collateralVaultFactoryData.abi,
    collateralVaultFactoryData.bytecode,
    wallet
  );

  const bondFactory = await BondFactory.deploy();
  await bondFactory.waitForDeployment();
  console.log(`bondFactory was deployed to ${bondFactory.target}`);
  await sleep(500);

  const BondMMFactory = new ethers.ContractFactory(
    bondMMFactoryData.abi,
    bondMMFactoryData.bytecode,
    wallet
  );

  const bondMMFactory = await BondMMFactory.deploy();
  await bondMMFactory.waitForDeployment();
  console.log(`bondMMFactory was deployed to ${bondMMFactory.target}`);
  await sleep(500);

  const collateralVaultFactory = await CollateralVaultFactory.deploy();
  await collateralVaultFactory.waitForDeployment();
  console.log(
    `collateralVaultFactory was deployed to ${collateralVaultFactory.target}`
  );
  await sleep(500);

  const bondMMRouter = await BondMMRouter.deploy(
    bondMMFactory.target,
    bondFactory.target,
    collateralVaultFactory.target
  );
  await bondMMRouter.waitForDeployment();
  console.log(`BondMMRouter was deployed to ${bondMMRouter.target}`);
  await sleep(1000);

  const wbnb = new ethers.Contract(
    tokens.BSC.WBNB.address,
    tokenData.abi,
    wallet
  );
  tx = await wbnb.approve(bondMMRouter.target, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  const wbnbPoolAddress = await bondMMRouter.initNewPool.staticCall(
    wbnb.target,
    BigInt(r0 * 10 ** 18),
    BigInt(r0 * 10 ** 18),
    BigInt(k0 * 10 ** 18),
    BigInt(10 ** 7) * BigInt(10 ** 18),
    {
      liquidatedFee: 500,
      vault: vaultAddress,
      poolFee: {
        basedFee: 2,
        minFee: 1,
      },
      equityRiskRatio: BigInt(0.9 * 10 ** 4),
      gracePeriod: BigInt(1209600),
    }
  );

  console.log("wbnbPoolAddress:", wbnbPoolAddress);

  tx = await bondMMRouter.initNewPool(
    wbnb.target,
    BigInt(r0 * 10 ** 18),
    BigInt(r0 * 10 ** 18),
    BigInt(k0 * 10 ** 18),
    BigInt(10 ** 7 * 10 ** 18),
    {
      liquidatedFee: 20,
      vault: vaultAddress,
      poolFee: {
        basedFee: 2,
        minFee: 1,
      },
      equityRiskRatio: BigInt(0.9 * 10 ** 4),
      gracePeriod: BigInt(1209600),
    }
  );

  tx = await wbnb.approve(wbnbPoolAddress, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  console.log("add collateral tokens: starting....");

  tx = await bondMMRouter.addNewCollateralToken(wbnbPoolAddress, wbnb.target, {
    liquidationRatio: BigInt(1.5 * 10 ** 4),
    priceFeed: tokens.BSC.WBNB.priceFeed,
    ltv: BigInt(0.5 * 10 ** 4),
  });

  await tx.wait();
  await sleep(500);

  tx = await bondMMRouter.addNewCollateralToken(
    wbnbPoolAddress,
    tokens.BSC.WETH.address,
    {
      liquidationRatio: BigInt(1.5 * 10 ** 4),
      priceFeed: tokens.BSC.WETH.priceFeed,
      ltv: BigInt(0.5 * 10 ** 4),
    }
  );
  await tx.wait();
  await sleep(500);

  tx = await bondMMRouter.addNewCollateralToken(
    wbnbPoolAddress,
    tokens.BSC.BTCB.address,
    {
      liquidationRatio: BigInt(1.5 * 10 ** 4),
      priceFeed: tokens.BSC.BTCB.priceFeed,
      ltv: BigInt(0.5 * 10 ** 4),
    }
  );

  await tx.wait();
  await sleep(500);

  tx = await bondMMRouter.addNewCollateralToken(
    wbnbPoolAddress,
    tokens.BSC.slisBNB.address,
    {
      liquidationRatio: BigInt(1.8 * 10 ** 4),
      priceFeed: tokens.BSC.slisBNB.priceFeed,
      ltv: BigInt(0.5 * 10 ** 4),
    }
  );

  await tx.wait();
  await sleep(500);

  tx = await bondMMRouter.addNewCollateralToken(
    wbnbPoolAddress,
    tokens.BSC.CAKE.address,
    {
      liquidationRatio: BigInt(1.5 * 10 ** 4),
      priceFeed: tokens.BSC.CAKE.priceFeed,
      ltv: BigInt(0.5 * 10 ** 4),
    }
  );

  await tx.wait();
  await sleep(500);

  tx = await bondMMRouter.addNewCollateralToken(
    wbnbPoolAddress,
    tokens.BSC.USDT.address,
    {
      liquidationRatio: BigInt(1.2 * 10 ** 4),
      priceFeed: tokens.BSC.USDT.priceFeed,
      ltv: BigInt(0.8 * 10 ** 4),
    }
  );

  await tx.wait();
  await sleep(500);

  console.log("add collateral tokens for wbnb pool: done");

  // const BondPool = new ethers.ContractFactory(
  //   bondPoolData.abi,
  //   bondPoolData.bytecode,
  //   wallet
  // );

  // const bondPool = await BondPool.deploy(bondMMRouter.target);
  // await bondPool.waitForDeployment();
  // console.log(`BondPool was deployed to ${bondPool.target}`);

  const wbnbBondAddress = await bondMMRouter.getBondAddress(wbnbPoolAddress);
  console.log("wbnbBondAddress:", wbnbBondAddress);
  ///

  tx = await bondMMRouter.addMaturity(wbnbPoolAddress, 1728345600);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wbnbPoolAddress, 1728691200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wbnbPoolAddress, 1730678400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wbnbPoolAddress, 1735862400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wbnbPoolAddress, 1752019200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);
}

// We recommend this pattern to be able to use /await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// bondFactory was deployed to 0xA7fE6D806d8E770DC5075Ca894b5cf4b71DA59B5
// bondMMFactory was deployed to 0x71f7818F16C93cCe68B68Cb6C049b510B4251Df1
// BondMMRouter was deployed to 0x57eC5879F0fE89dED298D4573d96FdD28EA58075
// add collateral tokens: starting....
// add collateral tokens: done
// bondPoolAddress: 0xE3cD415c8CFb7F231926520b2f553C0Ae7FA9F60
// bondAddress: 0x7269b8c5623cb38662d4435855062527DF1C54B0
// add maturity
// add maturity
