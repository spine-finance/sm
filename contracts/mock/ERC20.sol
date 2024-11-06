// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        super._mint(msg.sender, 10 ** 28);
    }

    function mint(uint amount) external {
        super._mint(msg.sender, amount);
    }

    function mintTo(address to, uint amount) external {
        super._mint(to, amount);
    }

    function burn(address from, uint amount) external {
        super._burn(from, amount);
    }
}
