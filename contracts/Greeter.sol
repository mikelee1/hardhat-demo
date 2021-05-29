//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

// import "hardhat/console.sol";

// import "@Arachnid/solidity-stringutils/src/strings.sol"

contract Greeter {
    string greeting;

    constructor(string memory _greeting) {
        greeting = _greeting;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public {
        greeting = _greeting;
    }

    function getInvoker() public view returns (address) {
        return msg.sender;
    }
}
