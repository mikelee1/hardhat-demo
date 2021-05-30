//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

// pragma experimental ABIEncoderV2;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenContract is ERC20 {
    address admin;

    event Mint(address _receiver, uint256 _amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        admin = msg.sender;
    }

    function mint(address _account, uint256 _amount) public onlyAdmin {
        _mint(_account, _amount);
        emit Mint(_account, _amount);
    }

    modifier onlyAdmin {
        require(admin == msg.sender, "must admin");
        _;
    }
}
