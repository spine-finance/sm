// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ICollateralVaultFactory {
    function createCollateralVault(address _router) external returns (address);
}
