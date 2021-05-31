//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

// pragma experimental ABIEncoderV2;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NftContract is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;

    event Mint(address, string, string);

    constructor(string memory name, string memory symbol)
        public
        ERC721(name, symbol)
    {}

    function mint(
        address recipient,
        string memory hash,
        string memory metadata
    ) public returns (uint256) {
        require(hashes[hash] != 1, "hash already exist");
        hashes[hash] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        emit Mint(recipient, hash, metadata);
        return newItemId;
    }
}
