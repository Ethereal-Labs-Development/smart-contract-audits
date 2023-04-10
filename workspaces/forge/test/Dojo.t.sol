// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import "../src/projects/dojo/Dojo.sol";

contract DojoTest is Test {
    DojoCHIP public dojo;

    function setUp() public {
        dojo = new DojoCHIP();
    }

    /// @notice Sample test to log the variable's value.
    function test_deadAddress_Value() public {
        emit log_named_address("Dead Address", dojo.deadAddress());
    }

}
