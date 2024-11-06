// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBondMM.sol";
import "./interfaces/IBondToken.sol";
import "./types/utils.sol";
import "./interfaces/factories/IBondFactory.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract RestakingBondMM is IBondMM, ERC20 {
    IERC20 public quoteToken;
    IBondToken public bond;
    UD60x18 public r_star;
    uint256 public time;
    UD60x18 public k0; //
    bool isInitial;
    uint256 constant ONE = 10 ** 18;
    uint256 constant TEN_THOUSANDS = 10000;
    uint256 constant YEAR_SECONDS = 31536000;
    address vault;
    UD60x18 X;
    uint256 y;
    IBondFactory bondFactory;
    mapping(uint256 => bool) matureAt; // seconds
    mapping(uint256 => LoanData) loanData;
    uint256[] listMaturity;
    uint256 maturityNum;
    address immutable router;
    uint immutable maxMaturity;

    struct PoolState {
        UD60x18 x;
        UD60x18 y;
        UD60x18 alpha;
        UD60x18 K;
    }

    Fee poolFee;

    constructor(
        address _router,
        address _bondFactory,
        uint256 _maxMaturity
    ) ERC20("LP Shares", "LPS") {
        time = block.timestamp;
        router = _router;
        maxMaturity = _maxMaturity;
        bondFactory = IBondFactory(_bondFactory);
    }

    // Modifier

    modifier NotInitial() {
        require(!isInitial, "The pool is initialized");
        _;
    }

    modifier ValidMaturity(uint256 maturity) {
        require(
            block.timestamp <= maturity && matureAt[maturity],
            "This maturity is not exists"
        );
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Only router");
        _;
    }

    function shareBalanceOf(address account) public view returns (uint256) {
        return balanceOf(account);
    }

    function getEquity() public view returns (uint256) {
        uint256 E = y;
        for (uint256 i = 0; i < maturityNum; i++) {
            LoanData memory _loanData = loanData[listMaturity[i]];
            E = E + _loanData.b - _loanData.l;
        }
        return E;
    }

    function getX() external view returns (uint256) {
        return X.intoUint256();
    }

    // function getMinEquityFrom(
    //     uint256 maturity
    // ) public view returns (uint256 minE) {
    //     minE = quoteTokenAmount();
    //     for (uint256 i = 0; i < maturityNum; i++) {
    //         if (listMaturity[i] > maturity) continue;
    //         LoanData memory _loanData = loanData[listMaturity[i]];
    //         minE = minE + _loanData.b - _loanData.l;
    //     }
    // }

    function getTimeToMaturity(
        uint256 maturity
    ) internal view returns (UD60x18) {
        return ud(maturity - time).div(ud(YEAR_SECONDS));
    }

    function changeRStar(uint256 _r_star) external onlyRouter {
        r_star = ud(_r_star);
    }

    // r = k ln (X/y) + r*
    function getRate() private view returns (uint256, UD60x18) {
        UD60x18 _y = ud(y);
        UD60x18 _X = X;
        UD60x18 r;
        uint256 sign = 0;
        if (_X >= _y) {
            r = (_X / _y).ln() * k0 + r_star;
        } else {
            UD60x18 first_part = (_y / _X).ln() * k0;
            if (first_part <= r_star) {
                r = r_star - first_part;
            } else {
                r = first_part - r_star;
                sign = 1;
            }
        }
        return (sign, r);
    }

    function getUintRate() external view returns (uint256 sign, uint256 uintR) {
        UD60x18 r;
        (sign, r) = getRate();
        uintR = r.intoUint256();
    }

    // p = e^-rt
    function getBondPrice(uint256 maturity) internal view returns (UD60x18) {
        (uint256 sign_r, UD60x18 r) = getRate();
        UD60x18 t = getTimeToMaturity(maturity);
        if (sign_r == 0) return ((r * t).exp()).inv();
        return (r * t).exp();
    }

    function getUintBondPrice(
        uint256 maturity
    ) external view returns (uint256) {
        UD60x18 price = getBondPrice(maturity);
        return price.intoUint256();
    }

    function getListMaturity() external view returns (uint256[] memory) {
        return listMaturity;
    }

    function getLoanData()
        external
        view
        returns (uint256 lended, uint256 borrrowed)
    {
        for (uint256 i = 0; i < maturityNum; i++) {
            LoanData memory _loanData = loanData[listMaturity[i]];
            lended += _loanData.l;
            borrrowed += _loanData.b;
        }
    }

    function getLoanData(
        uint256 maturity
    ) external view returns (uint256 lended, uint256 borrrowed) {
        LoanData memory _loanData = loanData[maturity];
        lended = _loanData.l;
        borrrowed = _loanData.b;
    }

    function initPool(
        address _creator,
        address _quoteToken,
        uint256 _r0,
        uint256 _r_star,
        uint256 _k0,
        uint256 cashIn,
        uint256 initLPShares,
        address _vault,
        Fee calldata _fee
    ) external NotInitial onlyRouter returns (address bondAddress) {
        isInitial = true;
        if (_r0 == _r_star) {
            X = ud(cashIn);
        } else if (_r0 > _r_star) {
            X = (ud(_r0 - _r_star) / ud(_k0)).exp() * ud(cashIn);
        } else {
            X = ud(cashIn) / ((ud(_r_star - _r0) / ud(_k0)).exp());
        }
        y = cashIn;
        quoteToken = IERC20(_quoteToken);
        bondAddress = bondFactory.createBond(address(this));
        bond = IBondToken(bondAddress);
        k0 = ud(_k0);
        r_star = ud(_r_star);
        vault = _vault;
        poolFee = _fee;
        _mint(_creator, initLPShares);
    }

    function addMaturity(uint256 _maturity) external onlyRouter {
        require(_maturity <= maxMaturity, "Invalid maturity");
        matureAt[_maturity] = true;
        listMaturity.push(_maturity);
        maturityNum += 1;
    }

    function syncReward() public onlyRouter {
        uint256 y_new = IERC20(quoteToken).balanceOf(address(this));
        UD60x18 _X = X;
        X = (_X * ud(y_new)) / ud(y);
        y = y_new;
    }

    function addLiquidity(
        address lp,
        uint256 cashIn
    ) external onlyRouter returns (uint256 lpShares) {
        UD60x18 _X = X;
        uint256 E = getEquity();

        X = (_X * ud(y + cashIn)) / ud(y);
        y += cashIn;
        if (E == 0) {
            lpShares = cashIn;
        } else {
            lpShares = (cashIn * totalSupply()) / E;
        }

        _mint(lp, lpShares); // mint lpShares
    }

    function withdrawLiquidity(
        address lp,
        uint256 _lpShares
    ) external onlyRouter returns (uint256 cashOut) {
        uint256 shareBalance = balanceOf(lp);
        uint256 equity = getEquity();
        require(_lpShares <= shareBalance, "Not enough lpShares");
        UD60x18 _X = X;

        cashOut = (equity * _lpShares) / totalSupply();

        X = (_X * ud(y - cashOut)) / ud(y);
        y -= cashOut;
        //burn
        _burn(lp, _lpShares);
        //transfer out
        quoteToken.transfer(router, cashOut);
    }

    function redeem(
        address account,
        uint256 maturity
    ) external onlyRouter returns (uint256 cashOut) {
        require(
            matureAt[maturity] && block.timestamp > maturity,
            "Can't redeem before maturity"
        );
        cashOut = bond.balanceOf(account, maturity);
        bond.burn(account, maturity, cashOut);
        UD60x18 _X = X;
        X = (_X * ud(y - cashOut)) / ud(y);
        y -= cashOut;
        loanData[maturity].l -= cashOut;
        quoteToken.transfer(router, cashOut);
    }

    function repay(
        address account,
        uint256 cashIn,
        uint256 maturity
    ) external onlyRouter {
        require(
            matureAt[maturity] && block.timestamp > maturity,
            "Can't repay before maturity"
        );
        UD60x18 _X = X;
        X = (_X * ud(y + cashIn)) / ud(y);
        y += cashIn;
        loanData[maturity].b -= cashIn;
    }

    function swapBondForQuoteToken(
        address account,
        uint256 _amountIn,
        uint256 maturity,
        ACTION action
    ) public onlyRouter ValidMaturity(maturity) returns (uint256 amountOut) {
        bond.burn(account, maturity, _amountIn);
        PoolState memory poolState = _getCurrentPoolState(maturity);
        UD60x18 delta_x = ud(_amountIn);
        UD60x18 delta_y = poolState.y -
            (poolState.K.mul(poolState.x.pow(poolState.alpha)) +
                poolState.y.pow(poolState.alpha) -
                poolState.K.mul((poolState.x + delta_x).pow(poolState.alpha)))
                .pow(poolState.alpha.inv());

        uint256 uint_delta_y = delta_y.intoUint256();
        uint256 fee = _getFee(maturity);
        uint256 swapFee = (uint_delta_y * fee) / TEN_THOUSANDS;
        amountOut = uint_delta_y - swapFee;

        quoteToken.transfer(router, amountOut);

        _updateXY(poolState.y, delta_y, 1, poolState.alpha);
        _updateLoanData(maturity, action, _amountIn);
    }

    function swapQuoteTokenForExactBond(
        address account,
        uint256 _amountOut,
        uint256 maturity,
        ACTION action
    ) external onlyRouter ValidMaturity(maturity) returns (uint256 amountIn) {
        PoolState memory poolState = _getCurrentPoolState(maturity);
        require(
            _amountOut < poolState.x.intoUint256(),
            "_amountOut < poolState.x"
        );
        UD60x18 delta_x = ud(_amountOut);
        UD60x18 delta_y = (poolState.K.mul(poolState.x.pow(poolState.alpha)) +
            poolState.y.pow(poolState.alpha) -
            poolState.K.mul((poolState.x - delta_x).pow(poolState.alpha))).pow(
                poolState.alpha.inv()
            ) - poolState.y;
        uint256 uint_delta_y = delta_y.intoUint256();
        uint256 fee = _getFee(maturity);
        uint256 swapFee = (uint_delta_y * fee) / TEN_THOUSANDS;
        amountIn = uint_delta_y + swapFee;
        bond.mint(account, maturity, _amountOut);
        _updateXY(poolState.y, delta_y, 0, poolState.alpha);
        _updateLoanData(maturity, action, _amountOut);
    }

    function swapQuoteTokenForBond(
        address account,
        uint256 _amountIn,
        uint256 maturity,
        ACTION action
    ) public onlyRouter ValidMaturity(maturity) returns (uint256 amountOut) {
        PoolState memory poolState = _getCurrentPoolState(maturity);
        uint256 fee = _getFee(maturity);
        uint256 swapFee = (_amountIn * fee) / TEN_THOUSANDS;
        UD60x18 delta_y = ud(_amountIn);
        delta_y = delta_y - ud(swapFee);
        UD60x18 delta_x = poolState.x -
            (
                (poolState.K.mul(poolState.x.pow(poolState.alpha)) +
                    poolState.y.pow(poolState.alpha) -
                    (poolState.y + delta_y).pow(poolState.alpha)).div(
                        poolState.K
                    )
            ).pow(poolState.alpha.inv());
        amountOut = delta_x.intoUint256();
        bond.mint(account, maturity, amountOut);
        _updateXY(poolState.y, delta_y, 0, poolState.alpha);
        _updateLoanData(maturity, action, amountOut);
    }

    function swapBondMaturity(
        address account,
        uint256 bondAmountIn,
        uint _fromMaturity,
        uint _toMaturity,
        ACTION action
    )
        external
        onlyRouter
        ValidMaturity(_fromMaturity)
        ValidMaturity(_toMaturity)
        returns (uint256 bondAmountOut, uint256 tokenAmount)
    {
        ACTION firstAction = (action == ACTION.OB || action == ACTION.CB)
            ? ACTION.CB
            : ACTION.CL;
        tokenAmount = swapBondForQuoteToken(
            account,
            bondAmountIn,
            _fromMaturity,
            firstAction
        );
        ACTION secondAction = (action == ACTION.OB || action == ACTION.CB)
            ? ACTION.OB
            : ACTION.OL;
        bondAmountOut = swapQuoteTokenForBond(
            account,
            tokenAmount,
            _toMaturity,
            secondAction
        );
    }

    function mintBond(
        address _receiver,
        uint _maturity,
        uint _amount
    ) external onlyRouter {
        bond.mint(_receiver, _maturity, _amount);
    }

    function burnBond(
        address _from,
        uint _maturity,
        uint _amount
    ) external onlyRouter {
        bond.burn(_from, _maturity, _amount);
    }

    function estimateQuoteTokenAmountForExactBond(
        uint256 _amountOut,
        uint256 maturity
    ) external view returns (uint256 amountIn) {
        PoolState memory poolState = _getCurrentPoolState(maturity);
        UD60x18 delta_x = ud(_amountOut);
        UD60x18 delta_y = (poolState.K.mul(poolState.x.pow(poolState.alpha)) +
            poolState.y.pow(poolState.alpha) -
            poolState.K.mul((poolState.x - delta_x).pow(poolState.alpha))).pow(
                poolState.alpha.inv()
            ) - poolState.y;
        uint256 uint_delta_y = delta_y.intoUint256();
        uint256 fee = _getFee(maturity);
        amountIn = (uint_delta_y * (TEN_THOUSANDS - fee)) / TEN_THOUSANDS;
    }

    function estimateBondAmountForExactQuoteToken(
        uint256 _amountOut,
        uint256 maturity
    ) external view returns (uint256 amountIn) {
        PoolState memory poolState = _getCurrentPoolState(maturity);
        uint256 fee = _getFee(maturity);
        _amountOut = (_amountOut * TEN_THOUSANDS) / (TEN_THOUSANDS - fee);

        UD60x18 delta_y = ud(_amountOut);
        UD60x18 delta_x = (
            (poolState.K.mul(poolState.x.pow(poolState.alpha)) +
                poolState.y.pow(poolState.alpha) -
                (poolState.y - delta_y).pow(poolState.alpha)).div(poolState.K)
        ).pow(poolState.alpha.inv()) - poolState.x;
        amountIn = delta_x.intoUint256();
    }

    function _getCurrentPoolState(
        uint256 maturity
    ) private view returns (PoolState memory) {
        UD60x18 x = X / getBondPrice(maturity);
        UD60x18 alpha = _getAlpha(maturity);
        UD60x18 K = _getK(maturity);
        return PoolState(x, ud(y), alpha, K);
    }

    function _getFee(uint256 maturity) private view returns (uint256) {
        UD60x18 t = getTimeToMaturity(maturity);
        uint256 fee = ((t * ud(poolFee.basedFee * ONE))).intoUint256() / ONE;

        if (fee > poolFee.minFee) return fee;
        return poolFee.minFee;
    }

    // alpha = 1/(1+tk)
    function _getAlpha(uint256 maturity) private view returns (UD60x18) {
        UD60x18 t = getTimeToMaturity(maturity);
        return (ud(ONE) + t.mul(k0)).inv();
    }

    // K = 1/(e^((t*r_star)/(1+tk))
    function _getK(uint256 maturity) private view returns (UD60x18) {
        UD60x18 t = getTimeToMaturity(maturity);
        return (((t.mul(r_star)).div(ud(ONE) + t.mul(k0))).exp()).inv();
    }

    function _getMinEquityFrom(
        uint256 maturity
    ) internal view returns (uint256) {}

    function _updateXY(
        UD60x18 _y,
        UD60x18 deltaY,
        uint256 signDeltaY,
        UD60x18 alpha
    ) private {
        UD60x18 y_new;
        if (signDeltaY == 0) {
            y_new = _y + deltaY;
        } else {
            y_new = _y - deltaY;
        }
        X = y_new * ((_y / y_new).pow(alpha) * (X / _y + ud(ONE)) - ud(ONE));
        y = y_new.intoUint256();
    }

    function _updateLoanData(
        uint256 maturity,
        ACTION action,
        uint256 amount
    ) private {
        if (action == ACTION.OB) {
            loanData[maturity].b += amount;
        } else if (action == ACTION.OL) {
            loanData[maturity].l += amount;
        } else if (action == ACTION.CB) {
            loanData[maturity].b -= amount;
        } else if (action == ACTION.CL) {
            loanData[maturity].l -= amount;
        }
    }
}
