// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IBondMM.sol";
import "./interfaces/factories/IBondMMFactory.sol";
import "./interfaces/IBondToken.sol";
import "./interfaces/factories/ICollateralVaultFactory.sol";
import "./interfaces/ICollateralVault.sol";
import "./types/utils.sol";

contract Router is IRouter, Ownable {
    // mapping(uint => BorrowData) debtInfo;
    mapping(address => PoolData) pools;
    mapping(address => mapping(address => CollateralTokenData)) collateralTokenInfo;
    mapping(address => address[]) listCollateralAssets;
    mapping(address => mapping(address => mapping(address => uint256))) userDeposit;
    mapping(address => mapping(address => mapping(uint256 => uint256))) userBorrowed;
    uint constant TEN_THOUSANDS = 10000;
    uint constant MAX_INT = type(uint).max;

    IBondMMFactory immutable bondMMFactory;
    address immutable bondFactory;
    ICollateralVaultFactory immutable collateralVaultFactory;

    constructor(
        address _bondMMFactory,
        address _bondFactory,
        address _collateralVaultFactory
    ) Ownable(msg.sender) {
        bondMMFactory = IBondMMFactory(_bondMMFactory);
        bondFactory = _bondFactory;
        collateralVaultFactory = ICollateralVaultFactory(
            _collateralVaultFactory
        );
    }

    // modifier
    modifier CollateralLTVProtected(address _user, address _poolAddress) {
        _;
        uint256 maxBorrowingToken = calcMaxBorrowingToken(_user, _poolAddress);
        uint256 borrowedToken = _calcTotalBorrowedToken(_user, _poolAddress);
        require(maxBorrowingToken >= borrowedToken, "Collateral risk");
    }

    modifier onlyAdmin(address _poolAddress) {
        PoolData memory poolData = pools[_poolAddress];
        require(msg.sender == poolData.admin);
        _;
    }

    /// @notice	owner can create new lending pool
    /// @param _tokenAddress pool's quote token
    /// @param _r0 initial rate
    /// @param _r_star target rate
    /// @param _k0 price-volatility factor
    /// @param _tokenAmount init value of quote token
    /// @param _poolData configs
    function initNewPool(
        address _tokenAddress,
        uint _r0,
        uint _r_star,
        uint _k0,
        uint _tokenAmount,
        InitPoolData memory _poolData
    ) external returns (address) {
        address poolAddress = bondMMFactory.createBondMM(
            address(this),
            bondFactory,
            _poolData.maxMaturity
        );

        address collateralVault = collateralVaultFactory.createCollateralVault(
            address(this)
        );

        IBondMM newPool = IBondMM(poolAddress);
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        IERC20(_tokenAddress).approve(poolAddress, MAX_INT);
        ICollateralVault(collateralVault).approveToken(_tokenAddress);
        address bondAddress = newPool.initPool(
            msg.sender,
            _tokenAddress,
            _r0,
            _r_star,
            _k0,
            _tokenAmount,
            _tokenAmount, // init shares = token input
            _poolData.vault,
            _poolData.poolFee
        );
        pools[poolAddress] = PoolData(
            _poolData.tokenAddress,
            _poolData.liquidatedFee,
            bondAddress,
            _poolData.vault,
            true,
            _tokenAmount,
            msg.sender,
            _poolData.equityRiskRatio,
            _poolData.gracePeriod,
            _poolData.poolFee,
            collateralVault,
            _poolData.tokenAddress,
            _poolData.tokenPriceFeed
        );
        //
        emit PoolCreated(
            poolAddress,
            _tokenAddress,
            bondAddress,
            collateralVault
        );

        emit LiquidityAdded(
            msg.sender,
            poolAddress,
            _tokenAmount,
            _tokenAmount
        );
        return poolAddress;
    }

    function updateCollateralTokenInfo(
        address _poolAddress,
        address _token,
        CollateralTokenData memory _data
    ) external onlyAdmin(_poolAddress) {
        collateralTokenInfo[_poolAddress][_token] = _data;
        PoolData memory poolData = pools[_poolAddress];
        ICollateralVault(poolData.collateralVault).approveToken(_token);
    }

    function addNewCollateralToken(
        address _poolAddress,
        address _token,
        CollateralTokenData memory _data
    ) external onlyAdmin(_poolAddress) {
        require(
            collateralTokenInfo[_poolAddress][_token].liquidationRatio == 0,
            "Existed token"
        );
        listCollateralAssets[_poolAddress].push(_token);
        collateralTokenInfo[_poolAddress][_token] = _data;
        PoolData memory poolData = pools[_poolAddress];
        ICollateralVault(poolData.collateralVault).approveToken(_token);
        emit NewCollateralTokenAdded(
            _poolAddress,
            _token,
            _data.ltv,
            _data.liquidationRatio
        );
    }

    function removeCollateralToken(
        address _poolAddress,
        address _token
    ) external onlyAdmin(_poolAddress) {
        address[] storage listPoolCollateralAssets = listCollateralAssets[
            _poolAddress
        ];
        for (uint i = 0; i < listPoolCollateralAssets.length; i++) {
            if (listPoolCollateralAssets[i] == _token) {
                for (uint j = i; j < listPoolCollateralAssets.length - 1; j++) {
                    listPoolCollateralAssets[j] = listPoolCollateralAssets[
                        j + 1
                    ];
                }
                listPoolCollateralAssets.pop();
                break;
            }
        }
        delete collateralTokenInfo[_poolAddress][_token].liquidationRatio;
        delete collateralTokenInfo[_poolAddress][_token].priceFeed;
        delete collateralTokenInfo[_poolAddress][_token].ltv;
    }

    function getBondAddress(
        address _poolAddress
    ) external view returns (address) {
        PoolData memory poolData = pools[_poolAddress];
        return poolData.bondAddress;
    }

    function getBondPrice(
        address _poolAddress,
        uint256 _maturity
    ) external view returns (uint256) {
        return IBondMM(_poolAddress).getUintBondPrice(_maturity);
    }

    function getRate(address _poolAddress) public view returns (uint, uint256) {
        return IBondMM(_poolAddress).getUintRate();
    }

    function getEquity(address _poolAddress) public view returns (uint256) {
        return IBondMM(_poolAddress).getEquity();
    }

    function getTotalLiquidityDeposited(
        address _poolAddress
    ) external view returns (uint256) {
        return pools[_poolAddress].lpDepositAmount;
    }

    function getUserBorrowed(
        address _user,
        address _poolAddress,
        uint256 _maturity
    ) external view returns (uint256) {
        return userBorrowed[_user][_poolAddress][_maturity];
    }

    /// @notice owner can add _maturity
    function addMaturity(
        address _poolAddress,
        uint _maturity
    ) external onlyAdmin(_poolAddress) {
        IBondMM(_poolAddress).addMaturity(_maturity);
        emit MaturityAdded(_poolAddress, _maturity);
    }

    function pausePool(address _poolAddress) external onlyAdmin(_poolAddress) {
        IBondMM(_poolAddress).pause();
    }

    function unpausePool(
        address _poolAddress
    ) external onlyAdmin(_poolAddress) {
        IBondMM(_poolAddress).unpause();
    }

    // Deposit Collateral
    function depositCollateral(
        address _collateralToken,
        address _poolAddress,
        uint256 _amount
    ) external {
        PoolData memory poolData = pools[_poolAddress];
        IERC20(_collateralToken).transferFrom(
            msg.sender,
            poolData.collateralVault,
            _amount
        );
        userDeposit[msg.sender][_poolAddress][_collateralToken] += _amount;
        emit CollateralDeposited(
            msg.sender,
            _poolAddress,
            _collateralToken,
            _amount
        );
    }

    function getCollateralBalance(
        address _user,
        address _poolAddress,
        address _token
    ) external view returns (uint256) {
        return userDeposit[_user][_poolAddress][_token];
    }

    function withdrawCollateral(
        address _collateralToken,
        address _poolAddress,
        uint256 _amount
    ) external CollateralLTVProtected(msg.sender, _poolAddress) {
        PoolData memory poolData = pools[_poolAddress];
        userDeposit[msg.sender][_poolAddress][_collateralToken] -= _amount;

        IERC20(_collateralToken).transferFrom(
            poolData.collateralVault,
            msg.sender,
            _amount
        );
        emit CollateralWithdrawed(
            msg.sender,
            _poolAddress,
            _collateralToken,
            _amount
        );
    }

    function calcMaxBorrowingToken(
        address _borrower,
        address _poolAddress
    ) public view returns (uint256 _maxAmount) {
        uint _cashAmount = 0;
        address[] memory _listCollateralAssets = listCollateralAssets[
            _poolAddress
        ];
        address _borrowedToken = pools[_poolAddress].tokenAddress;
        address _borrowedTokenPriceFeed = pools[_poolAddress].tokenPriceFeed;

        for (uint i = 0; i < _listCollateralAssets.length; i++) {
            uint _collateralTokenAmount = userDeposit[_borrower][_poolAddress][
                _listCollateralAssets[i]
            ];
            if (_collateralTokenAmount == 0) continue;
            // calc collateral usd amount
            (, int _collateralTokenPrice, , , ) = AggregatorV3Interface(
                collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                    .priceFeed
            ).latestRoundData();

            uint priceDecimals = AggregatorV3Interface(
                collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                    .priceFeed
            ).decimals();
            uint tokenDecimals = IERC20Metadata(_listCollateralAssets[i])
                .decimals();
            _cashAmount +=
                //
                (((uint256(_collateralTokenPrice) * _collateralTokenAmount) *
                    collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                        .ltv) / TEN_THOUSANDS) /
                10 ** (tokenDecimals + priceDecimals);
        }

        (, int _borrowTokenPrice, , , ) = AggregatorV3Interface(
            _borrowedTokenPriceFeed
        ).latestRoundData();
        //
        uint borrowedTokenPriceDecimals = AggregatorV3Interface(
            _borrowedTokenPriceFeed
        ).decimals();
        uint borrowedTokenDecimals = IERC20Metadata(_borrowedToken).decimals();
        _maxAmount =
            (_cashAmount *
                10 ** (borrowedTokenPriceDecimals + borrowedTokenDecimals)) /
            uint(_borrowTokenPrice);
    }

    function calcTotalCollateralsBalance(
        address _borrower,
        address _poolAddress
    ) public view returns (uint256 _maxAmount) {
        uint _cashAmount = 0;
        address[] memory _listCollateralAssets = listCollateralAssets[
            _poolAddress
        ];
        address _borrowedToken = pools[_poolAddress].tokenAddress;
        address _borrowedTokenPriceFeed = pools[_poolAddress].tokenPriceFeed;

        for (uint i = 0; i < _listCollateralAssets.length; i++) {
            uint _collateralTokenAmount = userDeposit[_borrower][_poolAddress][
                _listCollateralAssets[i]
            ];
            if (_collateralTokenAmount == 0) continue;
            // calc collateral usd amount
            (, int _collateralTokenPrice, , , ) = AggregatorV3Interface(
                collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                    .priceFeed
            ).latestRoundData();
            //
            uint priceDecimals = AggregatorV3Interface(
                collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                    .priceFeed
            ).decimals();
            uint tokenDecimals = IERC20Metadata(_listCollateralAssets[i])
                .decimals();
            _cashAmount +=
                (uint256(_collateralTokenPrice) * _collateralTokenAmount) /
                10 ** (tokenDecimals + priceDecimals);
        }

        (, int _borrowTokenPrice, , , ) = AggregatorV3Interface(
            _borrowedTokenPriceFeed
        ).latestRoundData();
        //
        uint borrowedTokenPriceDecimals = AggregatorV3Interface(
            _borrowedTokenPriceFeed
        ).decimals();
        uint borrowedTokenDecimals = IERC20Metadata(_borrowedToken).decimals();
        _maxAmount =
            (_cashAmount *
                10 ** (borrowedTokenDecimals + borrowedTokenPriceDecimals)) /
            uint(_borrowTokenPrice);
    }

    function _calcLiquidationPoint(
        address _borrower,
        address _poolAddress
    ) internal view returns (uint256 _maxAmount) {
        uint _cashAmount = 0;
        address[] memory _listCollateralAssets = listCollateralAssets[
            _poolAddress
        ];
        address _borrowedToken = pools[_poolAddress].tokenAddress;
        address _borrowedTokenPriceFeed = pools[_poolAddress].tokenPriceFeed;

        for (uint i = 0; i < _listCollateralAssets.length; i++) {
            uint _collateralTokenAmount = userDeposit[_borrower][_poolAddress][
                _listCollateralAssets[i]
            ];
            if (_collateralTokenAmount == 0) continue;
            // calc collateral usd amount
            (, int _collateralTokenPrice, , , ) = AggregatorV3Interface(
                collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                    .priceFeed
            ).latestRoundData();

            uint priceDecimals = AggregatorV3Interface(
                collateralTokenInfo[_poolAddress][_listCollateralAssets[i]]
                    .priceFeed
            ).decimals();
            uint tokenDecimals = IERC20Metadata(_listCollateralAssets[i])
                .decimals();
            //
            _cashAmount +=
                (
                    (((uint256(_collateralTokenPrice) *
                        _collateralTokenAmount) * TEN_THOUSANDS) /
                        collateralTokenInfo[_poolAddress][
                            _listCollateralAssets[i]
                        ].liquidationRatio)
                ) /
                10 ** (tokenDecimals + priceDecimals);
        }

        (, int _borrowTokenPrice, , , ) = AggregatorV3Interface(
            _borrowedTokenPriceFeed
        ).latestRoundData();
        //
        uint borrowedTokenPriceDecimals = AggregatorV3Interface(
            _borrowedTokenPriceFeed
        ).decimals();
        uint borrowedTokenDecimals = IERC20Metadata(_borrowedToken).decimals();
        //
        _maxAmount =
            (_cashAmount *
                10 ** (borrowedTokenDecimals + borrowedTokenPriceDecimals)) /
            uint(_borrowTokenPrice);
    }

    function _calcTotalBorrowedToken(
        address _borrower,
        address _poolAddress
    ) internal view returns (uint _totalBorrowed) {
        uint[] memory listMaturity = IBondMM(_poolAddress).getListMaturity();
        for (uint i = 0; i < listMaturity.length; i++) {
            _totalBorrowed += userBorrowed[_borrower][_poolAddress][
                listMaturity[i]
            ];
        }
    }

    function calcAvailableToBorrow(
        address _borrower,
        address _poolAddress
    ) public view returns (uint) {
        return
            calcMaxBorrowingToken(_borrower, _poolAddress) -
            _calcTotalBorrowedToken(_borrower, _poolAddress);
    }

    function openBorrowingPosition(
        address _poolAddress,
        uint _tokenAmountOut,
        uint _maturity
    )
        external
        CollateralLTVProtected(msg.sender, _poolAddress)
        returns (uint bondAmount)
    {
        require(_tokenAmountOut > 0, "invalid amount");
        bondAmount = _openBorrowingPosition(
            _poolAddress,
            _tokenAmountOut,
            _maturity
        );
        userBorrowed[msg.sender][_poolAddress][_maturity] += bondAmount;
        emit BorrowingPositionOpened(
            msg.sender,
            _poolAddress,
            _maturity,
            _tokenAmountOut,
            bondAmount
        );
    }

    function closeBorrowingPositionEarly(
        address _poolAddress,
        uint _bondAmount,
        uint _maturity
    ) external returns (uint tokenAmountIn) {
        require(_bondAmount > 0, "invalid amount");

        tokenAmountIn = _closeBorrowingPositionEarly(
            msg.sender,
            _poolAddress,
            _maturity,
            _bondAmount
        );

        userBorrowed[msg.sender][_poolAddress][_maturity] -= _bondAmount;

        emit BorrowingPositionClosedEarly(
            msg.sender,
            _poolAddress,
            _maturity,
            tokenAmountIn,
            _bondAmount
        );
    }

    function openLendingPosition(
        address _poolAddress,
        uint _tokenAmountIn,
        uint _maturity
    ) external returns (uint bondAmount) {
        require(_tokenAmountIn > 0, "invalid amount");

        bondAmount = _openLendingPositionWithQuoteToken(
            msg.sender,
            _poolAddress,
            _tokenAmountIn,
            _maturity
        );
        PoolData memory poolData = pools[_poolAddress];
        uint256 minE = IBondMM(_poolAddress).getEquity();
        require(
            minE + _tokenAmountIn - bondAmount >=
                (poolData.equityRiskRatio * poolData.lpDepositAmount) /
                    TEN_THOUSANDS,
            "Reach equity risk"
        );
        (uint256 sign, ) = getRate(_poolAddress);
        require(sign == 0, "Negative rate");

        emit LendingPositionOpened(
            msg.sender,
            _poolAddress,
            _maturity,
            _tokenAmountIn,
            bondAmount
        );
    }

    function closeLendingPositionEarly(
        address _poolAddress,
        uint _bondAmount,
        uint _maturity
    ) external returns (uint tokenAmoutOut) {
        require(_bondAmount > 0, "invalid amount");

        uint _closedBondAmount = IBondToken(pools[_poolAddress].bondAddress)
            .balanceOf(msg.sender, _maturity);
        if (_closedBondAmount > _bondAmount) {
            _closedBondAmount = _bondAmount;
        }
        tokenAmoutOut = _closeLendingPositionEarly(
            msg.sender,
            _poolAddress,
            _closedBondAmount,
            _maturity
        );
        emit LendingPositionClosedEarly(
            msg.sender,
            _poolAddress,
            _maturity,
            tokenAmoutOut,
            _bondAmount
        );
    }

    function addLiquidity(
        address _poolAddress,
        uint _tokenAmountIn
    ) external returns (uint shares) {
        shares = _addLiquidity(msg.sender, _poolAddress, _tokenAmountIn);
        pools[_poolAddress].lpDepositAmount += _tokenAmountIn;
        emit LiquidityAdded(msg.sender, _poolAddress, _tokenAmountIn, shares);
    }

    function withdrawLiquidity(
        address _poolAddress,
        uint _shares
    ) external returns (uint amountOut) {
        uint shareBalance = IBondMM(_poolAddress).shareBalanceOf(msg.sender);
        require(shareBalance >= _shares, "Not enough shares");
        amountOut = _withdrawLiquidity(msg.sender, _poolAddress, _shares);
        pools[_poolAddress].lpDepositAmount -= amountOut;
        emit LiquidityRemoved(msg.sender, _poolAddress, amountOut, _shares);
    }

    function isLiquidatable(
        address _borrower,
        address _poolAddress
    ) public view returns (bool) {
        PoolData memory poolData = pools[_poolAddress];

        uint256 _maxBorrowingToken = _calcLiquidationPoint(
            _borrower,
            _poolAddress
        );
        uint256 _borrowedToken = _calcTotalBorrowedToken(
            _borrower,
            _poolAddress
        );
        if (_maxBorrowingToken < _borrowedToken) return true;
        uint[] memory listMaturity = IBondMM(_poolAddress).getListMaturity();
        for (uint256 i = 0; i < listMaturity.length; i++) {
            uint maturity = listMaturity[i];
            uint borrowedAmount = userBorrowed[_borrower][_poolAddress][
                maturity
            ];
            if (
                maturity + poolData.gracePeriod < block.timestamp &&
                borrowedAmount > 0
            ) return true;
        }

        return false;
    }

    function liquidate(address _borrower, address _poolAddress) external {
        require(isLiquidatable(_borrower, _poolAddress), "Not Liquidatable");
        PoolData memory poolData = pools[_poolAddress];
        uint256 collateralBalance = calcTotalCollateralsBalance(
            _borrower,
            _poolAddress
        );

        uint[] memory listMaturity = IBondMM(_poolAddress).getListMaturity();
        uint256 totalPaid = 0;
        for (uint256 i = 0; i < listMaturity.length; i++) {
            uint maturity = listMaturity[i];
            uint borrowedAmount = userBorrowed[_borrower][_poolAddress][
                maturity
            ];
            if (borrowedAmount > 0) {
                if (maturity <= block.timestamp) {
                    totalPaid += IBondMM(_poolAddress)
                        .swapQuoteTokenForExactBond(
                            msg.sender,
                            borrowedAmount,
                            maturity,
                            ACTION.CB
                        );
                    IBondMM(_poolAddress).burnBond(
                        msg.sender,
                        maturity,
                        borrowedAmount
                    );
                    userBorrowed[_borrower][_poolAddress][maturity] = 0;
                } else {
                    totalPaid += borrowedAmount;
                    IBondMM(_poolAddress).repay(
                        msg.sender,
                        borrowedAmount,
                        maturity
                    );
                }
            }
        }
        uint256 collateralBalanceAfterFee = (collateralBalance *
            (TEN_THOUSANDS - poolData.liquidatedFee)) / TEN_THOUSANDS;
        if (collateralBalanceAfterFee > totalPaid) {
            IERC20(poolData.tokenAddress).transferFrom(
                msg.sender,
                _borrower,
                collateralBalanceAfterFee - totalPaid
            );
        }

        // reset collaterals balance
        address[] memory _listCollateralAssets = listCollateralAssets[
            _poolAddress
        ];

        for (uint i = 0; i < _listCollateralAssets.length; i++) {
            userDeposit[msg.sender][_poolAddress][
                _listCollateralAssets[i]
            ] += userDeposit[_borrower][_poolAddress][_listCollateralAssets[i]];
            userDeposit[_borrower][_poolAddress][_listCollateralAssets[i]] = 0;
        }
    }

    function redeem(
        address _poolAddress,
        uint _maturity
    ) external returns (uint) {
        emit PositionRedeemed(msg.sender, _poolAddress, _maturity);
        return IBondMM(_poolAddress).redeem(msg.sender, _maturity);
    }

    function repay(
        address _poolAddress,
        uint256 _maturity
    ) external returns (uint cashIn) {
        PoolData memory poolData = pools[_poolAddress];
        require(
            block.timestamp < poolData.gracePeriod + _maturity,
            "Need to be called before grace period"
        );
        cashIn = userBorrowed[msg.sender][_poolAddress][_maturity];
        IBondMM(_poolAddress).repay(msg.sender, cashIn, _maturity);
        userBorrowed[msg.sender][_poolAddress][_maturity] = 0;
        emit PositionRepaid(msg.sender, _poolAddress, _maturity);
    }

    function swapLendingMaturity(
        uint _fromMaturity,
        uint _toMaturity,
        address _poolAddress,
        uint _bondAmount
    ) external returns (uint256 newBondAmount) {
        uint quoteTokenAmount = _closeLendingPositionEarly(
            msg.sender,
            _poolAddress,
            _bondAmount,
            _fromMaturity
        );
        newBondAmount = _openLendingPositionWithQuoteToken(
            msg.sender,
            _poolAddress,
            quoteTokenAmount,
            _toMaturity
        );
    }

    function swapBorrowingMaturity(
        uint _fromMaturity,
        uint _toMaturity,
        address _poolAddress,
        uint _bondAmount
    ) external returns (uint256) {
        userBorrowed[msg.sender][_poolAddress][_fromMaturity] -= _bondAmount;

        IBondMM(_poolAddress).mintBond(msg.sender, _fromMaturity, _bondAmount);

        (uint newBondAmount, uint tokenAmount) = IBondMM(_poolAddress)
            .swapBondMaturity(
                msg.sender,
                _bondAmount,
                _fromMaturity,
                _toMaturity,
                ACTION.OB
            );
        IBondMM(_poolAddress).burnBond(msg.sender, _toMaturity, newBondAmount);
        userBorrowed[msg.sender][_poolAddress][_toMaturity] += newBondAmount;
        emit BorrowingPositionClosedEarly(
            msg.sender,
            _poolAddress,
            _fromMaturity,
            tokenAmount,
            _bondAmount
        );
        emit BorrowingPositionOpened(
            msg.sender,
            _poolAddress,
            _toMaturity,
            tokenAmount,
            newBondAmount
        );
        return newBondAmount;
    }

    function _openBorrowingPosition(
        address _poolAddress,
        uint _tokenAmountOut,
        uint _maturity
    ) internal returns (uint bondAmount) {
        PoolData memory poolData = pools[_poolAddress];
        require(poolData.created, "Pool must be created");

        bondAmount = IBondMM(_poolAddress).estimateBondAmountForExactQuoteToken(
                _tokenAmountOut,
                _maturity
            );

        IBondMM(_poolAddress).mintBond(msg.sender, _maturity, bondAmount);
        IBondMM(_poolAddress).swapBondForQuoteToken(
            msg.sender,
            bondAmount,
            _maturity,
            ACTION.OB
        );
    }

    function _closeBorrowingPositionEarly(
        address _borrower,
        address _poolAddress,
        uint256 _maturity,
        uint256 _bondAmount
    ) internal returns (uint tokenAmountIn) {
        // swap cash to bond
        PoolData memory poolData = pools[_poolAddress];
        require(poolData.created, "Pool must be created");
        tokenAmountIn = IBondMM(_poolAddress).swapQuoteTokenForExactBond(
            _borrower,
            _bondAmount,
            _maturity,
            ACTION.CB
        );

        IBondMM(_poolAddress).burnBond(_borrower, _maturity, _bondAmount);
    }

    function _openLendingPositionWithQuoteToken(
        address _lender,
        address _poolAddress,
        uint _quoteTokenAmount,
        uint _maturity
    ) internal returns (uint bondAmount) {
        bondAmount = IBondMM(_poolAddress).swapQuoteTokenForBond(
            _lender,
            _quoteTokenAmount,
            _maturity,
            ACTION.OL
        );
    }

    function _closeLendingPositionEarly(
        address _lender,
        address _poolAddress,
        uint _bondAmount,
        uint _maturity
    ) internal returns (uint tokenAmountOut) {
        tokenAmountOut = IBondMM(_poolAddress).swapBondForQuoteToken(
            _lender,
            _bondAmount,
            _maturity,
            ACTION.CL
        );
    }

    function _addLiquidity(
        address lp,
        address _poolAddress,
        uint _tokenAmountIn
    ) internal returns (uint shares) {
        shares = IBondMM(_poolAddress).addLiquidity(lp, _tokenAmountIn);
    }

    function _withdrawLiquidity(
        address lp,
        address _poolAddress,
        uint _shares
    ) internal returns (uint) {
        uint tokenAmoutOut = IBondMM(_poolAddress).withdrawLiquidity(
            lp,
            _shares
        );
        return tokenAmoutOut;
    }
}
