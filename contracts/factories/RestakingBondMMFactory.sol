// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../RestakingBondMM.sol";
import "../interfaces/factories/IBondMMFactory.sol";

/// @title BondMMFactory
/// @notice create new bondMM pool
contract RestakingBondMMFactory is IBondMMFactory {
    constructor() {}

    function createBondMM(
        address _bondMMOwner,
        address _bondFactory,
        uint256 _maxMaturity
    ) external returns (address) {
        RestakingBondMM bondMM = new RestakingBondMM(
            _bondMMOwner,
            _bondFactory,
            _maxMaturity
        );
        return address(bondMM);
    }
}
