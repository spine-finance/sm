// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IBondMMFactory {
    function createBondMM(
        address _bondMMOwner,
        address _bondFactory,
        uint256 _maxMaturity
    ) external returns (address);
}
