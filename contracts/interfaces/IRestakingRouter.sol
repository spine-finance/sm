// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "../types/FeeType.sol";
import "../types/utils.sol";

interface IRestakingRouter {
    event PoolCreated(
        address poolAddress,
        address tokenAddress,
        address bondAddress,
        address collateralVault
    );

    event MaturityAdded(address poolAddress, uint256 maturity);

    event NewCollateralTokenAdded(
        address poolAddress,
        address token,
        uint256 ltv,
        uint256 liquidationRatio
    );

    event CollateralDeposited(
        address user,
        address pool,
        address token,
        uint256 amount
    );

    event CollateralWithdrawed(
        address user,
        address pool,
        address token,
        uint256 amount
    );

    event BorrowingPositionOpened(
        address user,
        address pool,
        uint256 maturity,
        uint256 tokenAmountOut,
        uint256 bondAmount
    );

    event BorrowingPositionClosedEarly(
        address user,
        address pool,
        uint256 maturity,
        uint256 tokenAmountIn,
        uint256 bondAmount
    );

    event PositionRepaid(address user, address pool, uint256 maturity);

    event LendingPositionOpened(
        address user,
        address pool,
        uint256 maturity,
        uint256 tokenAmountIn,
        uint256 bondAmount
    );

    event LendingPositionClosedEarly(
        address user,
        address pool,
        uint256 maturity,
        uint256 tokenAmountOut,
        uint256 bondAmount
    );

    event PositionRedeemed(address user, address pool, uint256 maturity);

    event LiquidityAdded(
        address user,
        address pool,
        uint256 amountIn,
        uint256 shareAmount
    );
    event LiquidityRemoved(
        address user,
        address pool,
        uint256 amountOut,
        uint256 shareAmount
    );

    function initNewPool(
        uint _r0,
        uint _k0,
        uint _tokenAmount,
        uint _initShares,
        InitPoolData memory _poolData
    ) external returns (address);

    function updateCollateralTokenInfo(
        address _poolAddress,
        address _token,
        CollateralTokenData memory _data
    ) external;

    function addNewCollateralToken(
        address _poolAddress,
        address _token,
        CollateralTokenData memory _data
    ) external;

    function removeCollateralToken(
        address _poolAddress,
        address _token
    ) external;

    function getBondAddress(
        address _poolAddress
    ) external view returns (address);

    function getBondPrice(
        address _poolAddress,
        uint _maturity
    ) external view returns (uint);

    function getRate(
        address _poolAddress
    ) external view returns (uint, uint256);

    function getEquity(address _poolAddress) external view returns (uint256);

    function getTotalLiquidityDeposited(
        address _poolAddress
    ) external view returns (uint256);

    function calcMaxBorrowingToken(
        address _borrower,
        address _poolAddress
    ) external view returns (uint256 _maxAmount);

    function calcAvailableToBorrow(
        address _borrower,
        address _poolAddress
    ) external view returns (uint);

    function getCollateralBalance(
        address _user,
        address _poolAddress,
        address _token
    ) external view returns (uint256);

    function openBorrowingPosition(
        address _poolAddress,
        uint _tokenAmountOut,
        uint _maturity
    ) external returns (uint bondAmount);

    function closeBorrowingPositionEarly(
        address _poolAddress,
        uint _bondAmount,
        uint _maturity
    ) external returns (uint tokenAmountIn);

    function openLendingPosition(
        address _poolAddress,
        uint _tokenAmountIn,
        uint _maturity
    ) external returns (uint tokenAmountIn);

    function closeLendingPositionEarly(
        address _poolAddress,
        uint _bondAmount,
        uint maturity
    ) external returns (uint);

    function swapBorrowingMaturity(
        uint _fromMaturity,
        uint _toMaturity,
        address _poolAddress,
        uint _bondAmount
    ) external returns (uint256 newBondAmount);

    function swapLendingMaturity(
        uint _fromMaturity,
        uint _toMaturity,
        address _poolAddress,
        uint _bondAmount
    ) external returns (uint256 newBondAmount);

    function redeem(
        address _poolAddress,
        uint _maturity
    ) external returns (uint);

    function repay(
        address _poolAddress,
        uint _maturity
    ) external returns (uint);

    function addLiquidity(
        address _poolAddress,
        uint _tokenAmountIn
    ) external returns (uint shares);

    function withdrawLiquidity(
        address _poolAddress,
        uint _shares
    ) external returns (uint amountOut);

    function depositCollateral(
        address _collateralToken,
        address _poolAddress,
        uint256 _amount
    ) external;

    function withdrawCollateral(
        address _collateralToken,
        address _poolAddress,
        uint256 _amount
    ) external;

    // function isLiquidatable(
    //     address _borrower,
    //     address _poolAddress
    // ) external view returns (bool);

    // function liquidate(address borrower, address _poolAddress) external;
}
