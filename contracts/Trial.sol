pragma solidity ^0.7.0;

contract Trial {
    bytes32 public aa = bytes32("PRIVATE");
    bytes32 public bb = bytes32("STAKE");

    constructor() {}
    
    function Keccak256(address owner, int24 tickLower, int24 tickUpper) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }
} 