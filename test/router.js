// This is an example test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai");

// We use `loadFixture` to share common setups (or fixtures) between tests.
// Using this simplifies your tests and makes them run faster, by taking
// advantage of Hardhat Network's snapshot functionality.
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// `describe` is a Mocha function that allows you to organize your tests.
// Having your tests organized makes debugging them easier. All Mocha
// functions are available in the global scope.
//
// `describe` receives the name of a section of your test suite, and a
// callback. The callback must define the tests of that section. This callback
// can't be an async function.
describe("Router contract", function () {
  // We define a fixture to reuse the same setup in every test. We use
  // loadFixture to run this setup once, snapshot that state, and reset Hardhat
  // Network to that snapshot in every test.
  async function deployRouterFixture() {
    // Get the Signers here.
    const [owner, addr1, addr2] = await ethers.getSigners();

    // To deploy our contract, we just have to call ethers.deployContract and await
    // its waitForDeployment() method, which happens once its transaction has been
    // mined.
    // Mock token and oracle
    const mockToken = await ethers.getContractFactory("MockToken");

    const USDC = await mockToken.deploy("usdc", "usdc");
    await USDC.waitForDeployment();
    const WETH = await mockToken.deploy("weth", "weth");
    await WETH.waitForDeployment();

    const mockOracle = await ethers.getContractFactory("MockOracle");

    const USDCOracle = await mockOracle.deploy(BigInt(1));
    await USDCOracle.waitForDeployment();
    const WETHOracle = await mockOracle.deploy(BigInt(4000));
    await WETHOracle.waitForDeployment();

    // Factories
    const BondMMFactory = await ethers.getContractFactory("BondMMFactory");
    const bondMMFactory = await BondMMFactory.deploy();
    await bondMMFactory.waitForDeployment();

    const BondFactory = await ethers.getContractFactory("BondFactory");
    const bondFactory = await BondFactory.deploy();
    await bondFactory.waitForDeployment();

    const CollateralVaultFactory = await ethers.getContractFactory(
      "CollateralVaultFactory"
    );
    const collateralVaultFactory = await CollateralVaultFactory.deploy();
    await collateralVaultFactory.waitForDeployment();

    // Router
    const Router = await ethers.getContractFactory("Router");
    const router = await Router.deploy(
      bondMMFactory.target,
      bondFactory.target,
      collateralVaultFactory.target
    );

    // Fixtures can return anything you consider useful for your tests
    return { router, owner, addr1, addr2, USDC, WETH, USDCOracle, WETHOracle };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { router, owner } = await loadFixture(deployRouterFixture);
      expect(await router.owner()).to.equal(owner.address);
    });
  });
  describe("Pool", function () {
    let usdcPoolAddress;
    let bondAddress;
    const maturity = 1752019200;
    let accounts = {};
    beforeEach(async function () {
      const { owner, router, USDC, WETH, USDCOracle, WETHOracle, addr1 } =
        await loadFixture(deployRouterFixture);
      accounts = { owner, router, USDC, WETH, USDCOracle, WETHOracle, addr1 };
      await USDC.approve(router.target, BigInt(10 ** 30));
      usdcPoolAddress = await router.initNewPool.staticCall(
        USDC.target,
        BigInt(0.05 * 10 ** 18),
        BigInt(0.05 * 10 ** 18),
        BigInt(0.1 * 10 ** 18),
        BigInt(10 ** 7) * BigInt(10 ** 18),
        {
          liquidatedFee: 500,
          vault: addr1.address,
          poolFee: {
            basedFee: 2,
            minFee: 1,
          },
          equityRiskRatio: BigInt(0.9 * 10 ** 4),
          gracePeriod: BigInt(1209600),
          maxMaturity: 1765228925,
          tokenPriceFeed: USDCOracle.target,
          tokenAddress: USDC.target,
          stakingTokenAddress: USDC.target,
        }
      );
      await router.initNewPool(
        USDC.target,
        BigInt(0.05 * 10 ** 18),
        BigInt(0.05 * 10 ** 18),
        BigInt(0.1 * 10 ** 18),
        BigInt(10 ** 7) * BigInt(10 ** 18),
        {
          liquidatedFee: 20,
          vault: addr1.address,
          poolFee: {
            basedFee: 2,
            minFee: 1,
          },
          equityRiskRatio: BigInt(0.9 * 10 ** 4),
          gracePeriod: BigInt(1209600),
          maxMaturity: 1765228925,
          tokenPriceFeed: USDCOracle.target,
          tokenAddress: USDC.target,
          stakingTokenAddress: USDC.target,
        }
      );
      await WETH.approve(usdcPoolAddress, BigInt(10 ** 30));
      await router.addNewCollateralToken(usdcPoolAddress, WETH.target, {
        liquidationRatio: BigInt(1.5 * 10 ** 4),
        priceFeed: WETHOracle.target,
        ltv: BigInt(0.5 * 10 ** 4),
      });
      await router.addMaturity(usdcPoolAddress, maturity);
    });
    it("Should init pool successfully", async function () {
      bondAddress = await accounts.router.getBondAddress(usdcPoolAddress);
      expect(bondAddress).to.not.equal("");
    });
    it("Should init rate correctly", async function () {
      const [_, rate] = await accounts.router.getRate(usdcPoolAddress);
      expect(rate).to.equal(BigInt((5 / 100) * 10 ** 18)); // r0 = 5%
    });

    it("Should init equity correctly", async function () {
      const equity = await accounts.router.getEquity(usdcPoolAddress);
      expect(equity).to.equal(BigInt(10 ** 7) * BigInt(10 ** 18)); // initial equity = 10M
    });

    it("Should lend correctly", async function () {
      const lendAmount = BigInt(10 ** 6) * BigInt(10 ** 8);
      const balanceBefore = await accounts.USDC.balanceOf(
        accounts.owner.address
      );
      await accounts.USDC.approve(usdcPoolAddress, lendAmount);
      await accounts.router.openLendingPosition(
        usdcPoolAddress,
        lendAmount,
        maturity
      );
      const balanceAfter = await accounts.USDC.balanceOf(
        accounts.owner.address
      );
      //correct amount
      expect(balanceAfter).to.equal(balanceBefore - lendAmount);
      // after lending action -> rate will reduce
      const [_, newRate] = await accounts.router.getRate(usdcPoolAddress);
      expect(newRate).to.lessThan(BigInt((5 / 100) * 10 ** 18));
    });
    it("Should close lend correctly", async function () {
      const lendAmount = BigInt(10 ** 6) * BigInt(10 ** 8);
      const balanceBefore = await accounts.USDC.balanceOf(
        accounts.owner.address
      );
      await accounts.USDC.approve(usdcPoolAddress, lendAmount);
      await accounts.router.openLendingPosition(
        usdcPoolAddress,
        lendAmount,
        maturity
      );
      const [, rate] = await accounts.router.getRate(usdcPoolAddress);

      const Bond = await ethers.getContractFactory("BondToken");
      const bond = await Bond.attach(bondAddress);
      const bondBalance = bond.balanceOf(accounts.owner.address, maturity);

      await accounts.router.closeLendingPositionEarly(
        usdcPoolAddress,
        bondBalance,
        maturity
      );
      const balanceAfter = await accounts.USDC.balanceOf(
        accounts.owner.address
      );
      //correct amount
      expect(balanceAfter).to.lessThan(balanceBefore); // due to fee
      // after lending action -> rate will reduce
      const [, newRate] = await accounts.router.getRate(usdcPoolAddress);
      expect(newRate).to.greaterThan(rate); // close lending -> increase rate
    });
    it("Should borrow correctly", async function () {
      const borrowAmount = BigInt(10 ** 6) * BigInt(10 ** 18);
      const balanceBefore = await accounts.USDC.balanceOf(
        accounts.owner.address
      );

      // DEPOSIT collateral
      await accounts.WETH.approve(accounts.router.target, borrowAmount);
      await accounts.router.depositCollateral(
        accounts.WETH.target,
        usdcPoolAddress,
        borrowAmount
      );

      // Borrow
      await accounts.router.openBorrowingPosition(
        usdcPoolAddress,
        borrowAmount,
        maturity
      );

      const balanceAfter = await accounts.USDC.balanceOf(
        accounts.owner.address
      );
      // after borrowing action -> rate will increase
      const [_, newRate] = await accounts.router.getRate(usdcPoolAddress);
      expect(newRate).to.greaterThan(BigInt((5 / 100) * 10 ** 18));
    });

    it("Should close borrow correctly", async function () {
      const borrowAmount = BigInt(10 ** 6) * BigInt(10 ** 18);
      const balanceBefore = await accounts.USDC.balanceOf(
        accounts.owner.address
      );

      // DEPOSIT collateral
      await accounts.WETH.approve(accounts.router.target, borrowAmount);
      await accounts.router.depositCollateral(
        accounts.WETH.target,
        usdcPoolAddress,
        borrowAmount
      );

      // Borrow
      await accounts.router.openBorrowingPosition(
        usdcPoolAddress,
        borrowAmount,
        maturity
      );
      const [, rate] = await accounts.router.getRate(usdcPoolAddress);

      //
      const borrowedBond = await accounts.router.getUserBorrowed(
        accounts.owner.address,
        usdcPoolAddress,
        maturity
      );
      //
      await accounts.USDC.approve(usdcPoolAddress, BigInt(10 ** 30));
      await accounts.router.closeBorrowingPositionEarly(
        usdcPoolAddress,
        borrowedBond,
        maturity
      );

      const balanceAfter = await accounts.USDC.balanceOf(
        accounts.owner.address
      );
      // correct amount
      expect(balanceAfter).to.lessThan(balanceBefore); // due to fee
      const [_, newRate] = await accounts.router.getRate(usdcPoolAddress);
      expect(newRate).to.lessThan(rate); // close borrow -> decrease rate
    });
  });
});
