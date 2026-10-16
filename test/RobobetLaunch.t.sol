// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {RobobetToken} from "../src/RobobetToken.sol";

/// @dev Local test fixture only; production deployment belongs to the launch infrastructure.
contract TokenFactoryFixture {
    function deploy(bytes32 salt) external returns (RobobetToken) {
        return new RobobetToken{salt: salt}();
    }

    function send(RobobetToken token, address recipient, uint256 amount) external {
        require(token.transfer(recipient, amount), "transfer failed");
    }
}

contract RejectsCallbacksFixture {
    fallback() external {
        revert("no callbacks accepted");
    }
}

contract RobobetLaunchTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 * 1e18;

    function test_Create2FactoryReceivesAllSupplyInsteadOfTransactionOrigin() public {
        TokenFactoryFixture factory = new TokenFactoryFixture();
        address initiator = makeAddr("launch initiator");
        bytes32 salt = keccak256("robobet launch test");
        address predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), address(factory), salt, keccak256(type(RobobetToken).creationCode)
                        )
                    )
                )
            )
        );

        vm.prank(initiator, initiator);
        RobobetToken token = factory.deploy(salt);

        assertEq(address(token), predicted);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(factory)), SUPPLY);
        assertEq(token.balanceOf(initiator), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(token)), 0);
    }

    /// @dev Tests token-level flows, not Uniswap pool pricing, liquidity accounting, or swaps.
    function test_DistributionClaimsAndPoolTransfersArriveWhole() public {
        TokenFactoryFixture factory = new TokenFactoryFixture();
        RobobetToken token = factory.deploy(keccak256("distribution"));
        address distributor = makeAddr("distributor fixture");
        address poolManager = makeAddr("pool manager fixture");
        address remainder = makeAddr("remainder fixture");
        address claimant = makeAddr("claimant fixture");
        address trader = makeAddr("trader fixture");
        address router = makeAddr("router fixture");

        factory.send(token, distributor, SUPPLY / 10);
        factory.send(token, poolManager, SUPPLY * 6 / 10);
        factory.send(token, remainder, SUPPLY * 3 / 10);

        assertEq(token.balanceOf(address(factory)), 0);
        assertEq(token.balanceOf(distributor), 100_000_000e18);
        assertEq(token.balanceOf(poolManager), 600_000_000e18);
        assertEq(token.balanceOf(remainder), 300_000_000e18);

        vm.prank(distributor);
        assertTrue(token.transfer(claimant, 100_000_000e18));
        assertEq(token.balanceOf(distributor), 0);
        assertEq(token.balanceOf(claimant), 100_000_000e18);

        vm.prank(poolManager);
        assertTrue(token.transfer(trader, 100e18));
        assertEq(token.balanceOf(trader), 100e18);
        vm.prank(trader);
        assertTrue(token.approve(router, 100e18));
        vm.prank(router);
        assertTrue(token.transferFrom(trader, poolManager, 100e18));
        assertEq(token.balanceOf(trader), 0);
        assertEq(token.balanceOf(poolManager), 600_000_000e18);
        assertEq(token.allowance(trader, router), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_TransfersDoNotCallRecipientCode() public {
        RobobetToken token = new RobobetToken();
        RejectsCallbacksFixture recipient = new RejectsCallbacksFixture();
        assertTrue(token.transfer(address(recipient), 1e18));
        assertEq(token.balanceOf(address(recipient)), 1e18);
    }
}
