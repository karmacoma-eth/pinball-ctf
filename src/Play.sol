pragma solidity 0.8.9;

import { Pinball } from "./Pinball.sol";

contract Play {
    bytes4 constant SELECT_MISSION_SELECTOR = 0x00e100ff;
    bytes4 constant COMPLETE_MISSION_SELECTOR = 0xF00FC7C8;
    bytes4 constant POWER_UP_SELECTOR = 0x01020304;
    bytes4 constant BUMPERS_SELECTOR = 0x50407060;

    bytes32[] MISSION_HASHES = [
        bytes32(0x38c56aa967695c50a998b7337e260fb29881ec07e0a0058ad892dcd973c016dc),
        bytes32(0x8f038627eb6f3adaddcfcb0c86b53e4e175b1d16ede665306e59d9752c7b2767),
        bytes32(0xfe7bec6d090ca50fa6998cf9b37c691deca00e1ab96f405c84eaa57895af7319),
        bytes32(0x46453a3e029b77b65084452c82951b4126bd91b5592ef3b88a8822e8c59b02e8)
    ];

    bytes1 constant PULL = "\x01";
    bytes1 constant TILT = "\x02";
    bytes1 constant FLIPLEFT = "\x03";
    bytes1 constant FLIPRIGHT = "\x04";

    // a virtual command that actually maps to FLIPLEFT
    // this is because the data for bumpers is not adjacent with the data of the other commands
    // (the second half of the ball is reserved for it)
    bytes1 constant FLIPLEFTBUMPERS = "\x42";

    uint16 constant INITIAL_DATA_OFFSET = 0xff;

    struct Command {
        bytes1 id;
        bytes2 data_offset;
        bytes2 data_length;
        bytes data;
    }

    event Log(uint);

    bytes ball;
    uint committedBlockNumber;
    Pinball immutable pinball;
    Command[] commands;

    constructor(Pinball _pinball) {
        pinball = _pinball;
    }

    function insertCoin() public {
        initBall();
        committedBlockNumber = block.number;
        pinball.insertCoins(keccak256(ball));
    }

    function play() public {
        pinball.play(ball, committedBlockNumber);
    }


    function initBall() public {
        ball.push('P');
        ball.push('C');
        ball.push('T');
        ball.push('F');

        // COMMANDS
        score_10652_commands();

        // cmd offset
        pushBytes2(0x0008);

        // cmd len
        pushBytes2(bytes2(uint16(commands.length)));

        // write out the commands
        for (uint i = 0; i < commands.length; i++) {
            if (commands[i].id == FLIPLEFTBUMPERS) {
                ball.push(FLIPLEFT);
            } else {
                ball.push(commands[i].id);
            }

            pushBytes2(commands[i].data_offset);
            pushBytes2(commands[i].data_length);
        }

        // reserve the rest of the space
        while (ball.length < 512) {
            ball.push("\x00");
        }

        // write out the data
        for (uint i = 0; i < commands.length; i++) {
            Command memory command = commands[i];

            if (command.id == FLIPLEFTBUMPERS) {
                writeBytes4(uint16(command.data_offset), BUMPERS_SELECTOR);
            } else {
                writeBytes(uint16(command.data_offset), command.data);
            }
        }

        // finalize the second half of the ball for BUMPERS
        uint expectedLocationAtBumpers = 0;
        prepareBallForBumpers(0x100, expectedLocationAtBumpers);
    }

    // COMMAND CONFIGURATIONS

    function score_3710_commands() internal {
        pull();

        flipRightSelectMission(
            0,    // currentMission
            77,   // expected location
            22292 // expected random
        );        // location 26 after this

        tilt(58, 10);

        flipLeftPowerUp(0, 26); // location 72 after this

        // flipRightCompleteMission(72); // not ideal, we should be closer to 66

        tilt(34, 10);

        flipRightSelectMission(0, 82, 0); // just to get a new location -> 39

        tilt(60, 10); // game over
    }


    function score_6770_commands() internal {
        pull();

        flipRightSelectMission(
            0,    // currentMission
            77,   // expected location
            22292 // expected random
        );        // location 26 after this

        tilt(58, 10);

        flipLeftPowerUp(0, 26);

        flipRightSelectMission(0, 72, 0); // just to get a new location -> 34

        tilt(39, 24);

        // got to have location as small as possible!
        // that's 100 bytes of data, yikes
        flipLeftPowerUp(1, 10); // new location is 60, yikes again

        tilt(75, 10); // game over
    }


    function score_1600_commands() internal {
        pull();

        tilt(92, 10); // ! \\

        flipRightSelectMission(
            0,    // currentMission
            77,   // expected location
            22292 // expected random
        );

        tilt(72, 10); // game over
    }


    function score_10652_commands() internal {
        pull();

        flipRightSelectMission(
            0,    // currentMission
            0x43, // expected location
            22292 // expected random
        );

        flipLeftPowerUp(0, 26);

        // ! \\ tiltPrice is 0x48!
        // setting tiltAmount so that we land at position 66, which gives us a skip of 3
        tilt(0x48, 8);

        flipRightCompleteMission(66);

        flipLeftBumpers();

        flipRightSelectMission(
            1,    // currentMission
            0x47, // expected location
            22292 // expected random
        );

        // tilt price is 97 -> game over
        tilt(97, 1);
    }


    // HELPER CORNER

    function command(bytes1 id, uint16 data_offset, bytes memory data) internal  pure returns(Command memory) {
        return Command(
            id,
            bytes2(data_offset),
            bytes2(uint16(data.length)),
            data
        );
    }

    function tilt(
        uint tiltPrice,
        uint tiltAmount
    ) internal {
        bytes memory data = new bytes(2);
        data[0] = bytes1(uint8(tiltPrice + 1));
        data[1] = bytes1(uint8(tiltAmount));

        commands.push(command(TILT, nextDataOffset(), data));
    }

    function pull() internal {
        bytes memory empty;
        commands.push(command(PULL, nextDataOffset(), empty));
    }

    function flipRightSelectMission(
        uint currentMission,
        uint expectedLocation,
        uint expectedRandom
    ) internal {
        bytes memory data = new bytes(36);

        writeBytes4(data, 0, SELECT_MISSION_SELECTOR);

        bytes32 inputHash = getInputHash(
            MISSION_HASHES[currentMission],
            bytes32(expectedLocation), // part
            uint32(expectedRandom));   // branch
        writeBytes32(data, 4, inputHash);

        commands.push(command(FLIPRIGHT, nextDataOffset(), data));
    }

    // 66 is the ideal location here to minimize skip
    function flipRightCompleteMission(
        uint expectedLocation
    ) internal {
        uint skip = 3 * (expectedLocation - 65);

        bytes memory data = new bytes(4 + 10 * skip);

        writeBytes4(data, 0, COMPLETE_MISSION_SELECTOR);

        // the accumulator that will let us complete the mission
        uint16[10] memory vector = [10, 6199, 41583, 35825, 48675, 54170, 30503, 57883, 63389, 60369];

        for (uint i = 0; i < 10; i += 1) {
            writeBytes2(data, 4 + i * skip, bytes2(vector[i]));
        }

        commands.push(command(FLIPRIGHT, nextDataOffset(), data));
    }

    function flipLeftPowerUp(uint8 currentPowerup, uint location) internal {
        uint checkAmount = 0;
        if (currentPowerup == 0) {
            checkAmount = 10;
        } else if (currentPowerup == 1) {
            checkAmount = 10 * location;
        } else if (currentPowerup == 2) {
            checkAmount = 10 ** location;
        }

        bytes memory data = new bytes(4 + checkAmount);
        writeBytes4(data, 0, POWER_UP_SELECTOR);

        for (uint i = 0; i < checkAmount; i += 1) {
            data[4 + i] = bytes1(uint8(0x65 + currentPowerup));
        }

        commands.push(command(FLIPLEFT, nextDataOffset(), data));
    }

    function flipLeftBumpers() internal {
        // need 4 bytes for the selector and 256 for the bumpers
        bytes memory empty;
        commands.push(Command(
            FLIPLEFTBUMPERS,
            bytes2(uint16(0x00ff - 4)),
            bytes2(uint16(256 + 4)),
            empty
        ));
    }

    function countBumpers(uint offset, uint expectedLocationAtBumpers) private returns(uint) {
        uint bumpers = 0;

        // count the number in the current configuration
        for (uint i = 0; i < 256; i++) {
            if (uint8(ball[offset + i]) == expectedLocationAtBumpers) {
                bumpers++;
            }
        }

        emit Log(bumpers);
        return bumpers;
    }

    function prepareBallForBumpers(uint offset, uint expectedLocationAtBumpers) private {
        // we need exactly 64
        uint bumpers = countBumpers(offset, expectedLocationAtBumpers);
        require(bumpers >= 64, "not enough bumpers!");

        // fill the end of the buffer until we get to the number we want
        for (uint i = 0; i <= (bumpers - 64); i++) {
            ball[offset + 256 - 1 - i] = 0x42;
        }
    }


    function writeBytes2(bytes memory data, uint offset, bytes2 value) pure private {
        data[offset + 0] = value[0];
        data[offset + 1] = value[1];
    }

    function writeBytes2(uint offset, bytes2 value) private {
        ball[offset + 0] = value[0];
        ball[offset + 1] = value[1];
    }

    function writeBytes4(bytes memory data, uint offset, bytes4 value) pure private {
        data[offset + 0] = value[0];
        data[offset + 1] = value[1];
        data[offset + 2] = value[2];
        data[offset + 3] = value[3];
    }

    function writeBytes4(uint offset, bytes4 value) private {
        ball[offset + 0] = value[0];
        ball[offset + 1] = value[1];
        ball[offset + 2] = value[2];
        ball[offset + 3] = value[3];
    }

    function writeBytes32(bytes memory data, uint offset, bytes32 value) pure private {
        for (uint i = 0; i < value.length; i += 1) {
            data[offset + i] = value[i];
        }
    }

    function writeBytes32(uint offset, bytes32 value) private {
        for (uint i = 0; i < value.length; i += 1) {
            ball[offset + i] = value[i];
        }
    }

    function writeBytes(uint offset, bytes memory value) private {
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

    function nextDataOffset() private view returns(uint16) {
        if (commands.length == 0) {
            return INITIAL_DATA_OFFSET;
        }

        Command memory lastCommand = commands[commands.length - 1];
        if (lastCommand.id == FLIPLEFTBUMPERS) {
            // TODO: can we have multiple FLIPLEFTBUMPERS in a row? Don't think so
            lastCommand = commands[commands.length - 2];
        }
        return uint16(lastCommand.data_offset) + uint16(lastCommand.data_length);
    }
}