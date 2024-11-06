// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../tokens/BondToken.sol";
import "../interfaces/factories/IBondFactory.sol";

/// @title BondFactory
/// @notice create new bond token
contract BondFactory is IBondFactory {
    constructor() {}

    function createBond(address _bondOwner) external returns (address) {
        BondToken bond = new BondToken(_bondOwner);
        return address(bond);
    }
}
