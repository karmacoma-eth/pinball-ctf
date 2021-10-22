// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "ds-test/test.sol";

import "./Accumulator.sol";


contract AccumulatorTest is DSTest {
    Accumulator accumulator;

    function setUp() public {
        accumulator = new Accumulator();
    }

    function proveFail_weShallActuallyPass(uint16[10] memory state) public {
        accumulator.youShallNotPass(state);
    }
}