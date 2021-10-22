pragma solidity 0.8.9;

import { Pinball } from "./Pinball.sol";

contract Play {
    bytes ball;
    uint committedBlockNumber;

    Pinball immutable pinball;

    constructor(Pinball _pinball) {
        pinball = _pinball;
    }

    function writeBytes4(uint offset, bytes4 value) private {
        ball[offset + 0] = value[0];
        ball[offset + 1] = value[1];
        ball[offset + 2] = value[2];
        ball[offset + 3] = value[3];
    }

    function writeBytes32(uint offset, bytes32 value) private {
        for (uint i = 0; i < value.length; i += 1) {
            ball[offset + i] = value[i];
        }
    }

    function getInputHash(bytes32 desiredHash, bytes32 part, uint32 branch) pure public returns(bytes32) {
        bytes32 hash = desiredHash;
        for (uint i = 0; i < 32; i++) {
            if (branch & 0x1 == 0x1)
                hash ^= part;
            branch >> 1;
            part << 8;
        }

        return hash;
    }

    function initBall() public {
        bytes1 PULL = "\x01";
        bytes1 TILT = "\x02";
        bytes1 FLIPRIGHT = "\x04";
        bytes1 FLIPLEFT = "\x03";

        ball.push('P');
        ball.push('C');
        ball.push('T');
        ball.push('F');

        // cmd offset
        ball.push("\x00");
        ball.push("\x08");

        // cmd len
        ball.push("\x00");
        ball.push("\x03");

        // cmd 1
        ball.push(PULL);
        ball.push("\x00");
        ball.push("\x00");
        ball.push("\x00");
        ball.push("\x00");

        // cmd 2
        ball.push(FLIPRIGHT);
        ball.push("\x00");
        ball.push("\xff"); // data offset
        ball.push("\x00");
        ball.push("\x00");

        // cmd 3
        ball.push(FLIPLEFT);
        ball.push("\x01");
        ball.push("\x23"); // data offset, 0xff + 4 + 32
        ball.push("\x00");
        ball.push("\x00");

        while (ball.length < 512) {
            ball.push("\x00");
        }

        // data
        writeBytes4(0xff, 0x00e100ff);

        bytes32 mission1Hash = 0x38c56aa967695c50a998b7337e260fb29881ec07e0a0058ad892dcd973c016dc;
        bytes32 inputHash = getInputHash(
            mission1Hash,
            0x0000000000000000000000000000000000000000000000000000000000000043, // part
            22292); // branch
        writeBytes32(0xff + 4, inputHash);

        // data for flipleft
        writeBytes4(0x123, 0x01020304);
        for (uint i = 0; i < 10; i += 1) {
            ball[0x127 + i] = "\x65";
        }
    }

    function insertCoin() public {
        initBall();
        committedBlockNumber = block.number;
        pinball.insertCoins(keccak256(ball));
    }

    function play() public {
        pinball.play(ball, committedBlockNumber);
    }
}