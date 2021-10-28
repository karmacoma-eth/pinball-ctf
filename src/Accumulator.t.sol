// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "ds-test/test.sol";

contract AccumulatorTest is DSTest {
    function youShallNotPass(uint16[10] memory inputs) pure public {
        uint32 accumulator = 1;

        unchecked {
            for (uint i = 0; i < 10; i++) {
                accumulator *= uint32(inputs[i]);
            }
        }

        require(accumulator == 0x020c020c, "incorrect accumulator");
    }

    function proveFail_weShallActuallyPass(uint16[10] memory inputs) public {
        youShallNotPass(inputs);
    }

    function proveFail_weShallActuallyPassWithConstraints(uint16[10] memory inputs) public {
        // require(inputs[0] == 0x0104); // <--- can't get this constraint to be satisfied
        require(inputs[1] == 1);
        require(inputs[2] & 0xff00 == 0xff00);
        youShallNotPass(inputs);
    }
}