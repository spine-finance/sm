// SPDX-License-Identifier: UNLICENSED
import "./FeeType.sol";
pragma solidity ^0.8.19;
enum ACTION {
    OL,
    CL,
    OB,
    CB
}

struct LoanData {
    uint256 b;
    uint256 l;
}

struct PoolData {
    address tokenAddress;
    uint16 liquidatedFee;
    address bondAddress;
    address vault;
    bool created;
    uint256 lpDepositAmount;
    address admin;
    uint16 equityRiskRatio;
    uint32 gracePeriod;
    Fee poolFee;
    address collateralVault;
    address stakingTokenAddress;
}

struct InitPoolData {
    address vault;
    uint16 liquidatedFee;
    Fee poolFee;
    uint16 equityRiskRatio;
    uint32 gracePeriod;
    uint256 maxMaturity;
    address tokenAddress;
    address stakingTokenAddress;
}

struct BorrowData {
    uint256 bondAmount;
    uint256 maturity;
    address poolAddress;
    bool isOpen;
}

struct CollateralTokenData {
    uint256 liquidationRatio;
    address priceFeed;
    uint256 ltv;
}
