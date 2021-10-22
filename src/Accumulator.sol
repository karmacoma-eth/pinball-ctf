pragma solidity 0.8.9;

contract Accumulator {
    function youShallNotPass(uint16[10] memory state) pure public {
        uint32 accumulator = 1;

        unchecked {
            for (uint i = 0; i < 10; i++) {
                accumulator *= uint32(state[i]);
            }
        }

        require(accumulator == 0x020c020c, "incorrect accumulator");
    }
}