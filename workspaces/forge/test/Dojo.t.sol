// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/projects/dojo/Dojo.sol";

contract DojoTest is Test {
    DojoCHIP public dojo;

    function setUp() public {
        dojo = new DojoCHIP();
    }
}
