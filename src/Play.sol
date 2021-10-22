pragma solidity 0.8.9;

import { Pinball } from "./Pinball.sol";

contract Play {
    bytes ball;
    uint committedBlockNumber;

    Pinball immutable pinball;

    bytes1 PULL = "\x01";
    bytes1 TILT = "\x02";
    bytes1 FLIPRIGHT = "\x04";
    bytes1 FLIPLEFT = "\x03";

    struct Command {
        bytes1 id;
        bytes2 data_offset;
        bytes2 data_length;
    }

    Command[] commands;

    constructor(Pinball _pinball) {
        pinball = _pinball;
    }

    function writeBytes2(uint offset, bytes2 value) private {
        ball[offset + 0] = value[0];
        ball[offset + 1] = value[1];
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

    function pushBytes2(bytes2 value) private {
        ball.push(value[0]);
        ball.push(value[1]);
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

    function nextDataOffset() private returns(bytes2) {
        Command memory lastCommand = commands[commands.length - 1];
        return bytes2(uint16(lastCommand.data_offset) + uint16(lastCommand.data_length));
    }

    function initBall() public {
        ball.push('P');
        ball.push('C');
        ball.push('T');
        ball.push('F');

        commands.push(Command(
            PULL,
            0x0000,
            0x0000
        ));

        commands.push(Command(
            FLIPRIGHT,
            0x00ff, // data offset
            0x0000
        ));

        commands.push(Command(
            FLIPLEFT,
            0x0123, // data offset
            0x000e
        ));

        bytes2 tiltDataOffset = nextDataOffset();
        commands.push(Command(
            TILT,
            tiltDataOffset,
            0x0002
        ));

        bytes2 fliprightDataOffset2 = nextDataOffset();
        commands.push(Command(
            FLIPRIGHT,
            fliprightDataOffset2,
            0x000e
        ));

        // cmd offset
        pushBytes2(0x0008);

        // cmd len
        pushBytes2(bytes2(uint16(commands.length)));

        for (uint i = 0; i < commands.length; i++) {
            ball.push(commands[i].id);
            pushBytes2(commands[i].data_offset);
            pushBytes2(commands[i].data_length);
        }

        while (ball.length < 512) {
            ball.push("\x00");
        }

        // data
        writeBytes4(0xff, 0x00e100ff); // selector

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

        // data for tilt
        // tiltPrice is 0x48
        // setting tiltAmount so that we land at position 66, which gives us a skip of 3
        writeBytes2(uint16(tiltDataOffset), 0x4908);

        // data for 2nd flip right
        writeBytes4(uint16(fliprightDataOffset2), 0xF00FC7C8); // selector

        // the accumulator that will let us complete the mission
        uint skip = 3;
        uint16[10] memory vector = [10, 6199, 41583, 35825, 48675, 54170, 30503, 57883, 63389, 60369];

        for (uint i = 0; i < 10; i += 1) {
            writeBytes2(uint16(fliprightDataOffset2) + 4 + i * skip, bytes2(vector[i]));
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