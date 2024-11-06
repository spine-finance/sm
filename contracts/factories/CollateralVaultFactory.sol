// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "../vaults/CollateralVault.sol";

contract CollateralVaultFactory {
    constructor() {}

    function createCollateralVault(address _router) external returns (address) {
        CollateralVault vault = new CollateralVault(_router);
        return address(vault);
    }
}
