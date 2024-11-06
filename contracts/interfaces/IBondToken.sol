// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IBondToken is IERC1155 {
    function mint(address to, uint256 id, uint256 amount) external;

    function burn(address from, uint id, uint amount) external;

    function totalSupply(uint expiration) external view returns (uint256);
}
