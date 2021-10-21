pragma solidity 0.8.9;

import { Pinball } from "./Pinball.sol";

contract Play {
    bytes ball;
    uint committedBlockNumber;

    Pinball immutable pinball;

    constructor(Pinball _pinball) {
        pinball = _pinball;
    }

    function initBall() public {
        ball.push('P');
        ball.push('C');
        ball.push('T');
        ball.push('F');

        // cmd offset
        ball.push("\x00");
        ball.push("\x08");

        // cmd len
        ball.push("\x00");
        ball.push("\x01");

        // cmd 1: pull
        ball.push("\x01");

        while (ball.length < 512) {
            ball.push("\x00");
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