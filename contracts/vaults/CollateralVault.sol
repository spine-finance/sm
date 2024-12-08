// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICollateralVault.sol";

contract CollateralVault is ICollateralVault {
    address immutable router;
    uint constant MAX_INT = type(uint).max;

    constructor(address _router) {
        router = _router;
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Only Router");
        _;
    }

    function approveToken(address token) external onlyRouter {
        IERC20(token).approve(msg.sender, MAX_INT);
    }
}
