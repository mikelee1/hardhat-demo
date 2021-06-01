//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

// pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

contract LotteryContract {
    address public admin;
    address payable[] gamblers;

    event enterGameEvent(address _gambler);
    event startGameEvent(address _gambler);

    constructor() public {
        admin = msg.sender;
    }

    function enterGame() public payable {
        require(msg.value == 1, "invalid value");
        gamblers.push(msg.sender);
        emit enterGameEvent(msg.sender);
    }

    function startGame() public onlyAdmin returns (address) {
        uint256 n = winnerNumber();
        address payable winner = gamblers[n];
        winner.transfer(address(this).balance);
        emit startGameEvent(winner);
        return winner;
    }

    function winnerNumber() private returns (uint256) {
        uint256 winner =
            uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) %
                gamblers.length;
        return winner;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "need admin");
        _;
    }
}
