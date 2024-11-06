// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IBondFactory {
    function createBond(address _bondOwner) external returns (address);
}
