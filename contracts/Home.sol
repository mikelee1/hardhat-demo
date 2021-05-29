//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
// pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

contract Home {
    address internal admin;
    address internal greeter;
    struct User {
        bool isVaild;
        string name;
        string profile;
        uint8 age;
    }
    mapping(address => User) users;

    event UpdateProfile(address _sender, string _profile);

    constructor(address _greeter) {
        admin = msg.sender;
        greeter = _greeter;
    }

    function createUser(
        address _address,
        string calldata _name,
        string calldata _profile,
        uint8 _age
    ) public onlyAdmin {
        User memory _user;
        _user.isVaild = true;
        _user.name = _name;
        _user.profile = _profile;
        _user.age = _age;
        users[_address] = _user;
    }

    function updateProfile(string memory _profile) public isValid {
        User memory _user = users[msg.sender];
        _user.profile = _profile;
        users[msg.sender] = _user;
        emit UpdateProfile(msg.sender, _profile);
    }

    function queryMyInfo()
        public
        view
        isValid
        returns (
            string memory,
            string memory,
            uint8
        )
    {
        User memory user = users[msg.sender];
        return (user.name, user.profile, user.age);
    }

    modifier isValid {
        require(users[msg.sender].isVaild, "user is invalid");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "");
        _;
    }
}
