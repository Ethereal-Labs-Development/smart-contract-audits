// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import { DojoCHIP } from "../src/projects/dojo/Unflattened/DojoCHIP.sol";

contract DojoTest is Test {
    DojoCHIP public dojo;

    function setUp() public {
        dojo = new DojoCHIP();
    }

    /// @notice Sample test to log the variable's value.
    function test_dojo_Constructor() public {
        emit log_named_uint("Total supply", dojo.totalSupply());
        emit log_named_uint("Owner balance", dojo.balanceOf(address(this)));

        emit log_named_uint("Maximum transaction amount", dojo.maxTransactionAmount());
        emit log_named_uint("Swap tokens at amount", dojo.swapTokensAtAmount());
        emit log_named_uint("Maximum wallet balance", dojo.maxWallet());
    }

    function test_dojo_updateDelayDigit_LockTransfers() public {
        // average number of blocks mined per day
        uint256 blocksMined = 7066;
        // maximum number of blocks user must wait before next transfer
        uint256 maxDelay = type(uint256).max;

        uint256 numYears = maxDelay / (blocksMined * 365);
        emit log_named_uint("Potential wait time in years", numYears);
    }

    function test_dojo_updateSwapTokensAtAmount_UpdateAmount() public {
        uint256 totalSupply = 9_000_000_000_000;

        emit log_named_uint("Swap tokens at amount before", dojo.swapTokensAtAmount());
        emit log_named_uint("Minimum swap amount", (dojo.totalSupply() * 1 / 100000) / 1e6);
        emit log_named_uint("Maximum swap amount", (dojo.totalSupply() * 5 / 1000) / 1e6);
        uint256 newAmount = (totalSupply / 100000) / 1e6;
        dojo.updateSwapTokensAtAmount(newAmount);
        emit log_named_uint("Swap tokens at amount after", dojo.swapTokensAtAmount());
        emit log_named_uint("newAmount", newAmount);

    }

}
