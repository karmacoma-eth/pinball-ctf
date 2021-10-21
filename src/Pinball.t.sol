// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Pinball.sol";
import "./Play.sol";

// using https://kndrck.co/posts/hevm_seth_cheatsheet/

abstract contract Hevm {
    // sets the block timestamp to x
    function warp(uint x) public virtual;
    // sets the block number to x
    function roll(uint x) public virtual;
    // sets the slot loc of contract c to val
    function store(address c, bytes32 loc, bytes32 val) public virtual;
    // reads the slot loc of contract c
    // function store(address c, bytes32 loc, bytes32 val) public virtual;
}

contract PinballTest is DSTest {
    Hevm hevm;
    Pinball pinball;
    Play play;

    function setUp() public {
        pinball = new Pinball();
        play = new Play(pinball);
        hevm = Hevm(HEVM_ADDRESS);
    }

    function test_play() public {

        play.insertCoin();

        hevm.roll(42);

        play.play();
    }
}
