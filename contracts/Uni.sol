//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IUniToken.sol";
import "hardhat/console.sol";

contract Uni {
    address uni;

    constructor(address _uni) {
        uni = _uni;
    }

    function totalSupply() external view returns (uint256) {
        return IUniToken(uni).totalSupply();
    }

    function name() external view returns (string memory) {
        return IUniToken(uni).name();
    }

    function symbol() external view returns (string memory) {
        return IUniToken(uni).symbol();
    }

    function minter() external view returns (address) {
        return IUniToken(uni).minter();
    }

    // fallback() external payable {
    //     console.log("in fallback");
    // }
}
