pragma solidity ^0.8.9;

import "../interfaces/Aave/IPool.sol";
import "./ERC20.sol";

contract MockAAvePool is IPool {
    address immutable underlyingAsset;
    address immutable aToken;

    constructor(address _token, address _aToken) {
        underlyingAsset = _token;
        aToken = _aToken;
    }

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        ERC20(asset).transferFrom(msg.sender, address(this), amount);
        MockToken(aToken).mintTo(onBehalfOf, amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        MockToken(aToken).burn(msg.sender, amount);
        ERC20(asset).transfer(to, amount);
        return amount;
    }
}
