// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "ds-test/test.sol";

contract AccumulatorTest is DSTest {
    function youShallNotPass(uint16[10] memory state) pure public {
        uint32 accumulator = 1;

        unchecked {
            for (uint i = 0; i < 10; i++) {
                accumulator *= uint32(state[i]);
            }
        }

        require(accumulator == 0x020c020c, "incorrect accumulator");
    }

    function proveFail_weShallActuallyPass(uint16[10] memory state) public {
        youShallNotPass(state);
    }
}