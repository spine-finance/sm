// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BondToken is ERC1155, Ownable {
    mapping(uint => uint) total_supply;

    constructor(address owner) ERC1155("uri") Ownable(owner) {}

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
        total_supply[id] += amount;
    }

    function burn(address from, uint id, uint amount) external onlyOwner {
        _burn(from, id, amount);
        total_supply[id] -= amount;
    }

    function totalSupply(uint expiration) external view returns (uint256) {
        return total_supply[expiration];
    }
}
