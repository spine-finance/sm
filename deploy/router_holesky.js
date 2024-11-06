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
    WBNBPool: {
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
  },
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
    USDePool: {
      USDe: {
        address: "0x799bC7b2511Eb9b16C3167427bE3EF5877eCf463",
        priceFeed: "0x8D27d12e330EAc733b75e21DB7b3dB8FdfFe65b1",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
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
      wstETH: {
        address: "0x3FCa3fbEa34af485ff9E5fBdE3f765b5855a36BE",
        priceFeed: "0xC98A962072e9ef4EFA464e40260A846268301666",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      sUSDe: {
        address: "0xabD6B47Bfd93EBfA57b2Cd2Ed935990c615aF162",
        priceFeed: "0xD2B1dA87d3210d0eef04baBEf771D9dE735C9251",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      sDAI: {
        address: "0x46fb9F2fFc5D85fac9f3061366F0D628303B1dEC",
        priceFeed: "0xC6a94A77df5a9512bbf4F32c3d87d4f438cF7A7E",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
    },
    WETHPool: {
      WETH: {
        address: "0xca5b8be68ad7c298b2eaa8f6b25d05721d151648",
        priceFeed: "0xae7c2c295e3e600269036e68fceb5f6eae0c7e53",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      wstETH: {
        address: "0x3FCa3fbEa34af485ff9E5fBdE3f765b5855a36BE",
        priceFeed: "0xC98A962072e9ef4EFA464e40260A846268301666",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      WBTC: {
        address: "0x115956a99104994bce0a854c320ea090624ae823",
        priceFeed: "0x58414bdbeb3de68f066598cd755be1b6e991aa08",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      cbETH: {
        address: "0x690b9c392276e602D8540b5dA7894D194C20FBc1",
        priceFeed: "0x8Ff166Bd2573Ee6b0af1cDa152Dc0167056bb83f",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      rsETH: {
        address: "0x50CDC77a041EA4FFC76AfbbF581Ad4d17763F50C",
        priceFeed: "0x524feb244B9bB0c17A76250F6AA22aACA4174143",
        liquidationRatio: 1.5,
        ltv: 0.2,
      },

      ezETH: {
        address: "0x91B856E8518F2B3EcE8A2Ac80dA14A179F15eCB9",
        priceFeed: "0x9f2Ac94076B314B286B93b47e450CD82b504485C",
        liquidationRatio: 1.5,
        ltv: 0.2,
      },

      rETH: {
        address: "0x24e00711aa1E3Cbf940196Ac84e9dec86A97A4Bf",
        priceFeed: "0x7273Bf825C03744195aB2de499bF0c6e9bd8E9fD",
        liquidationRatio: 1.5,
        ltv: 0.5,
      },
      osETH: {
        address: "0x3166F48A7240439729FB4eA911dE5Edcf4193934",
        priceFeed: "0x97D7682CfA24502f4Ae9b0294B480210ab633173",
        liquidationRatio: 1.5,
        ltv: 0.2,
      },
      weETH: {
        address: "0x2CAa3250E51Fb24BEc149E3364E960297237492F",
        priceFeed: "0xB8d01E1505E16F4307A43AFeD12531e1409367ef",
        liquidationRatio: 1.5,
        ltv: 0.2,
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

  const usdc = new ethers.Contract(
    tokens.HOLESKY.USDCPool.USDC.address,
    tokenData.abi,
    wallet
  );
  tx = await usdc.approve(bondMMRouter.target, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  const usdcPoolAddress = await bondMMRouter.initNewPool.staticCall(
    usdc.target,
    BigInt(0.05 * 10 ** 18),
    BigInt(0.05 * 10 ** 18),
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

  console.log("usdcPoolAddress:", usdcPoolAddress);

  tx = await bondMMRouter.initNewPool(
    usdc.target,
    BigInt(0.05 * 10 ** 18),
    BigInt(0.05 * 10 ** 18),
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

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1728345600);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1728691200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1730678400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1735862400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdcPoolAddress, 1752019200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  //   /// USDe
  const usde = new ethers.Contract(
    tokens.HOLESKY.USDePool.USDe.address,
    tokenData.abi,
    wallet
  );
  tx = await usde.approve(bondMMRouter.target, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  const usdePoolAddress = await bondMMRouter.initNewPool.staticCall(
    usde.target,
    BigInt(0.05 * 10 ** 18),
    BigInt(0.05 * 10 ** 18),
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

  console.log("usdePoolAddress:", usdePoolAddress);

  tx = await bondMMRouter.initNewPool(
    usde.target,
    BigInt(0.05 * 10 ** 18),
    BigInt(0.05 * 10 ** 18),
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

  tx = await usde.approve(usdePoolAddress, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  console.log("add collateral tokens: starting....");

  for (const key in tokens.HOLESKY.USDePool) {
    tx = await bondMMRouter.addNewCollateralToken(
      usdePoolAddress,
      tokens.HOLESKY.USDePool[key].address,
      {
        liquidationRatio: BigInt(
          tokens.HOLESKY.USDePool[key].liquidationRatio * 10 ** 4
        ),
        priceFeed: tokens.HOLESKY.USDePool[key].priceFeed,
        ltv: BigInt(tokens.HOLESKY.USDePool[key].ltv * 10 ** 4),
      }
    );
    await tx.wait();
    await sleep(500);
  }

  console.log("add collateral tokens for usde pool: done");

  const usdeBondAddress = await bondMMRouter.getBondAddress(usdePoolAddress);
  console.log("usdeBondAddress:", usdeBondAddress);
  ///

  tx = await bondMMRouter.addMaturity(usdePoolAddress, 1728345600);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdePoolAddress, 1728691200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdePoolAddress, 1730678400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdePoolAddress, 1735862400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(usdePoolAddress, 1752019200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  /// WETH
  const weth = new ethers.Contract(
    tokens.HOLESKY.WETHPool.WETH.address,
    tokenData.abi,
    wallet
  );
  tx = await weth.approve(bondMMRouter.target, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  const wethPoolAddress = await bondMMRouter.initNewPool.staticCall(
    weth.target,
    BigInt(0.01 * 10 ** 18),
    BigInt(0.01 * 10 ** 18),
    BigInt(k0 * 10 ** 18),
    BigInt(10 ** 3) * BigInt(10 ** 18),
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

  console.log("wethPoolAddress:", wethPoolAddress);

  tx = await bondMMRouter.initNewPool(
    weth.target,
    BigInt(0.01 * 10 ** 18),
    BigInt(0.01 * 10 ** 18),
    BigInt(k0 * 10 ** 18),
    BigInt(10 ** 3 * 10 ** 18),
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

  tx = await weth.approve(wethPoolAddress, BigInt(10 ** 30));
  await tx.wait();
  await sleep(500);

  console.log("add collateral tokens: starting....");

  for (const key in tokens.HOLESKY.WETHPool) {
    tx = await bondMMRouter.addNewCollateralToken(
      wethPoolAddress,
      tokens.HOLESKY.WETHPool[key].address,
      {
        liquidationRatio: BigInt(
          tokens.HOLESKY.WETHPool[key].liquidationRatio * 10 ** 4
        ),
        priceFeed: tokens.HOLESKY.WETHPool[key].priceFeed,
        ltv: BigInt(tokens.HOLESKY.WETHPool[key].ltv * 10 ** 4),
      }
    );
    await tx.wait();
    await sleep(500);
  }

  console.log("add collateral tokens for weth pool: done");

  const wethBondAddress = await bondMMRouter.getBondAddress(wethPoolAddress);
  console.log("wethBondAddress:", wethBondAddress);
  ///

  tx = await bondMMRouter.addMaturity(wethPoolAddress, 1728345600);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wethPoolAddress, 1728691200);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wethPoolAddress, 1730678400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wethPoolAddress, 1735862400);
  await tx.wait();
  console.log("add maturity");
  await sleep(1000);

  tx = await bondMMRouter.addMaturity(wethPoolAddress, 1752019200);
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
