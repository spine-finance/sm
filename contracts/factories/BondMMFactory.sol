// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../BondMM.sol";
import "../interfaces/factories/IBondMMFactory.sol";

/// @title BondMMFactory
/// @notice create new bondMM pool
contract BondMMFactory is IBondMMFactory {
    constructor() {}

    function createBondMM(
        address _bondMMOwner,
        address _bondFactory,
        uint256 _maxMaturity
    ) external returns (address) {
        BondMM bondMM = new BondMM(_bondMMOwner, _bondFactory, _maxMaturity);
        return address(bondMM);
    }
}
