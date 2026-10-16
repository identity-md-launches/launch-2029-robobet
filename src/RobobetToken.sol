// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title robobet (ROBOBET)
/// @notice Put your fate in the hands of SUPERINTELLIGENCE — robobet.fun
/// @dev Fixed supply, minted once to the immediate deployer (the factory at launch).
///      No owner, external mint/burn functions, transfer fees, or administrative controls.
contract RobobetToken is ERC20 {
    /// @notice One billion tokens expressed in the token's 18-decimal base units.
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("robobet", "ROBOBET") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
