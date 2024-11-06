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
const bondMMRouterData = require("../artifacts/contracts/RestakingRouter.sol/RestakingRouter.json");
// const bondMMData = require("../artifacts/contracts/BondMM.sol/BondMM.json");
const bondMMFactoryData = require("../artifacts/contracts/factories/RestakingBondMMFactory.sol/RestakingBondMMFactory.json");
const bondFactoryData = require("../artifacts/contracts/factories/BondFactory.sol/BondFactory.json");
// const mockOracleData = require("../artifacts/contracts/mock/MockStablecoinOracle.sol");
const mockAavePoolData = require("../artifacts/contracts/mock/MockAavePool.sol/MockAavePool.json");
const addressZero = "0x0000000000000000000000000000000000000000";
const r0 = 0.02;
const k0 = 0.1;
const vaultAddress = "0x46037fb19526bCe3BAbEF30D03242e8ED68c1b77";
const collateralVaultFactoryData = require("../artifacts/contracts/factories/CollateralVaultFactory.sol/CollateralVaultFactory.json");
const aUSDCAddeess = "0xAf074B2559811D4fB735909c58DF9eC6a0c07b9E";
const tokens = {
  HOLESKY: {
    USDCPool: {
      WETH: {
        address: "0xca5b8be68ad7c298b2eaa8f6b25d05721d151648",
        priceFeed: "0xae7c2c295e3e600269036e68fceb5f6eae0c7e53",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      WBTC: {
        address: "0x115956a99104994bce0a854c320ea090624ae823",
        priceFeed: "0x58414bdbeb3de68f066598cd755be1b6e991aa08",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      UNI: {
        address: "0xe246b12b6f197057b3a24a62cbc729c67bfbddb4",
        priceFeed: "0x1b3254d1e605d2d045238b2ea24011e91efd5fe4",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      LINK: {
        address: "0xCbB15E7eA0Eab2854273C066512a99b66B280535",
        priceFeed: "0xe6d673218adeb5d4445f060c250bff84724cb8d0",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      USDC: {
        address: "0x037d14d75F2dABc169a2E8Bf0FC36d690Df5980B",
        priceFeed: "0x8980e60fb3158271bcca7c0b7d6a7259a2885541",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
    },
  },
};
async function main() {
  const rpc = "https://ethereum-holesky-rpc.publicnode.com";
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
  const MockAavePool = new ethers.ContractFactory(
    mockAavePoolData.abi,
    mockAavePoolData.bytecode,
    wallet
  );

  const BondMMFactory = new ethers.ContractFactory(
    bondMMFactoryData.abi,
    bondMMFactoryData.bytecode,
    wallet
  );
  const usdc = new ethers.Contract(
    tokens.HOLESKY.USDCPool.USDC.address,
    tokenData.abi,
    wallet
  );

  const bondFactory = await BondFactory.deploy();
  await bondFactory.waitForDeployment();
  console.log(`bondFactory was deployed to ${bondFactory.target}`);
  await sleep(500);
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

  const mockAavePool = await MockAavePool.deploy(usdc.target, aUSDCAddeess);

  await mockAavePool.waitForDeployment();
  console.log(`mockAavePool was deployed to ${mockAavePool.target}`);

  const bondMMRouter = await BondMMRouter.deploy(
    bondMMFactory.target,
    bondFactory.target,
    collateralVaultFactory.target,
    mockAavePool.target
  );
  await bondMMRouter.waitForDeployment();
  console.log(`BondMMRouter was deployed to ${bondMMRouter.target}`);
  await sleep(1000);
  // const bondMMRouter = new ethers.Contract(
  //   "0x6f25BDfF144E1d01dAc1E100ce08A5c17a98e6aC",
  //   bondMMRouterData.abi,
  //   wallet
  // );
  tx = await usdc.approve(bondMMRouter.target, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  const usdcPoolAddress = await bondMMRouter.initNewPool.staticCall(
    BigInt(0.05 * 10 ** 18),
    BigInt(0.05 * 10 ** 18),
    BigInt(k0 * 10 ** 18),
    BigInt(10 ** 7) * BigInt(10 ** 18),
    {
      vault: vaultAddress,
      liquidatedFee: 500,
      poolFee: {
        basedFee: 2,
        minFee: 1,
      },
      equityRiskRatio: BigInt(0.9 * 10 ** 4),
      gracePeriod: BigInt(1209600),
      maxMaturity: BigInt(10 ** 30),
      tokenAddress: usdc.target,
      stakingTokenAddress: aUSDCAddeess,
    }
  );
  console.log("usdcPoolAddress:", usdcPoolAddress);

  tx = await bondMMRouter.initNewPool(
    BigInt(0.05 * 10 ** 18),
    BigInt(0.05 * 10 ** 18),
    BigInt(k0 * 10 ** 18),
    BigInt(10 ** 7 * 10 ** 18),
    {
      liquidatedFee: 500,
      vault: vaultAddress,
      poolFee: {
        basedFee: 2,
        minFee: 1,
      },
      equityRiskRatio: BigInt(0.9 * 10 ** 4),
      gracePeriod: BigInt(1209600),
      maxMaturity: BigInt(10 ** 30),
      tokenAddress: usdc.target,
      stakingTokenAddress: aUSDCAddeess,
    }
  );
  await tx.wait();
  await sleep(500);

  tx = await usdc.approve(usdcPoolAddress, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  console.log("add collateral tokens: starting....");

  for (const key in tokens.HOLESKY.USDCPool) {
    tx = await bondMMRouter.addNewCollateralToken(
      usdcPoolAddress,
      tokens.HOLESKY.USDCPool[key].address,
      {
        liquidationRatio: BigInt(1.5 * 10 ** 4),
        priceFeed: tokens.HOLESKY.USDCPool[key].priceFeed,
        ltv: BigInt(0.5 * 10 ** 4),
      }
    );
    await tx.wait();
    await sleep(500);
  }

  console.log("add collateral tokens for usdc pool: done");

  const usdcBondAddress = await bondMMRouter.getBondAddress(usdcPoolAddress);
  console.log("usdcBondAddress:", usdcBondAddress);

  // tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1728345600);
  // await tx.wait();
  // console.log("add maturity");
  // await sleep(1000);

  // tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1728691200);
  // await tx.wait();
  // console.log("add maturity");
  // await sleep(1000);

  // tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1730678400);
  // await tx.wait();
  // console.log("add maturity");
  // await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1735862400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1752019200);
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
