//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

// pragma experimental ABIEncoderV2;

// import "hardhat/console.sol";

contract TradeContract {
    uint256 defaultRatio;
    uint256 tradeCount;
    uint256 interval;
    mapping(uint256 => Trade) trades;

    enum State {Created, Locked, Released}
    struct Trade {
        uint256 value; //unit: wei
        State state;
        address buyer;
        address seller;
    }

    event CreateTradeEvent(uint256 _tradeId);

    constructor(uint256 _ratio, uint256 _interval) {
        defaultRatio = _ratio;
        interval = _interval;
    }

    function createTrade(uint256 _value) public payable newTradeCheck(_value) {
        Trade memory _trade;
        _trade.value = _value;
        _trade.state = State.Created;
        _trade.seller = msg.sender;
        trades[tradeCount] = _trade;
        emit CreateTradeEvent(tradeCount);
        tradeCount++;
    }

    function queryTrade(uint256 _tradeId)
        public
        view
        returns (
            address,
            address,
            uint256,
            State
        )
    {
        Trade memory trade = trades[_tradeId];
        return (trade.seller, trade.buyer, trade.value, trade.state);
    }

    modifier newTradeCheck(uint256 _value) {
        require(msg.value >= _value * defaultRatio, "value is invalid");
        _;
    }
}
