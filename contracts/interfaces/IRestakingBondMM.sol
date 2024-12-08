// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "../types/FeeType.sol";
import "../types/utils.sol";

interface IRestakingBondMM {
    function shareBalanceOf(address) external returns (uint);

    function getUintRate() external view returns (uint256, uint256);

    function getEquity() external view returns (uint);

    function getUintBondPrice(uint maturity) external view returns (uint);

    function getMinEquityFrom(uint256 maturity) external view returns (uint256);

    function getListMaturity() external view returns (uint256[] memory);

    function getLoanData()
        external
        view
        returns (uint256 lended, uint256 borrrowed);

    function getLoanData(
        uint256 maturity
    ) external view returns (uint256 lended, uint256 borrrowed);

    function addMaturity(uint maturity) external;

    function initPool(
        address _creator,
        address _quoteToken,
        uint _r0,
        uint _r_star,
        uint _k0,
        uint cashIn,
        uint initShares,
        address _vault,
        Fee calldata _fee
    ) external returns (address bondAddress);

    function mintBond(address _receiver, uint _maturity, uint _amount) external;

    function burnBond(address _from, uint _maturity, uint _amount) external;

    function addLiquidity(
        address lp,
        uint cashIn
    ) external returns (uint shares);

    function withdrawLiquidity(
        address lp,
        uint _shares
    ) external returns (uint cashOut);

    function redeem(
        address account,
        uint maturity
    ) external returns (uint cashOut);

    function repay(address account, uint256 cashIn, uint256 maturity) external;

    function swapBondForQuoteToken(
        address account,
        uint _amountIn,
        uint maturity,
        ACTION action
    ) external returns (uint amountOut);

    function swapQuoteTokenForExactBond(
        address account,
        uint _amountOut,
        uint maturity,
        ACTION action
    ) external returns (uint amountIn);

    function swapQuoteTokenForBond(
        address account,
        uint _amountIn,
        uint maturity,
        ACTION action
    ) external returns (uint amountIn);

    function swapBondMaturity(
        address account,
        uint256 bondAmountIn,
        uint _fromMaturity,
        uint _toMaturity,
        ACTION action
    ) external returns (uint256 bondAmountOut, uint256 tokenAmount);

    // function estimateQuoteTokenAmountForExactBond(
    //     uint _amountOut,
    //     uint maturity
    // ) external view returns (uint amountIn);

    function estimateBondAmountForExactQuoteToken(
        uint _amountOut,
        uint maturity
    ) external view returns (uint amountIn);

    function syncReward() external;

    function pause() external;

    function unpause() external;
}
