//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

// pragma experimental ABIEncoderV2;

// import "hardhat/console.sol";

contract TradeContract {
    uint256 defaultRatio;
    uint256 tradeCount;
    uint256 interval;
    Trade[] trades;

    enum State {Created, Locked, Released}
    struct Trade {
        uint256 value; //unit: wei
        State state;
        address buyer;
        address seller;
    }

    event CreateTradeEvent(uint256 _tradeId);
    event DepositTradeEvent(uint256 _tradeId);
    event BuyTradeEvent(uint256 _tradeId);
    event WithdrawEvent(uint256 _tradeId, address _invoker);

    constructor(uint256 _ratio, uint256 _interval) {
        defaultRatio = _ratio;
        interval = _interval;
    }

    function createTrade(uint256 _value)
        public
        payable
        checkDepositTradeValue(_value)
    {
        Trade memory _trade;
        _trade.value = _value;
        _trade.state = State.Created;
        _trade.seller = msg.sender;
        trades.push(_trade);
        emit CreateTradeEvent(tradeCount);
        tradeCount++;
    }

    function depositTrade(uint256 _tradeId)
        public
        payable
        checkTradeId(_tradeId)
        checkTradeBuyer(trades[_tradeId].buyer)
        checkDepositTradeValue(trades[_tradeId].value)
    {
        trades[_tradeId].buyer = msg.sender;
        trades[_tradeId].state = State.Locked;
        emit DepositTradeEvent(_tradeId);
    }

    function buyTrade(uint256 _tradeId)
        public
        payable
        checkTradeId(_tradeId)
        checkTradeValue(trades[_tradeId].value)
        checkTradeState(trades[_tradeId].state, State.Locked)
    {
        trades[_tradeId].buyer = msg.sender;
        trades[_tradeId].state = State.Locked;
        emit BuyTradeEvent(_tradeId);
    }

    function withdraw(uint256 _tradeId) public payable checkTradeId(_tradeId) {
        if (msg.sender == trades[_tradeId].buyer) {
            msg.sender.transfer(trades[_tradeId].value);
            trades[_tradeId].state = State.Released;
        } else if (
            msg.sender == trades[_tradeId].seller &&
            trades[_tradeId].state == State.Released
        ) {
            msg.sender.transfer(trades[_tradeId].value);
        } else {
            revert("invalid withdraw order");
        }

        emit WithdrawEvent(_tradeId, msg.sender);
    }

    function queryTrade(uint256 _tradeId)
        public
        view
        checkTradeId(_tradeId)
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

    modifier checkTradeId(uint256 _tradeId) {
        require(_tradeId < tradeCount, "invalid tradeId");
        _;
    }

    modifier checkTradeBuyer(address _buyer) {
        require(_buyer == address(0), "invalid buyer");
        _;
    }

    modifier checkDepositTradeValue(uint256 _value) {
        require(msg.value >= _value * defaultRatio, "invalid deposit value");
        _;
    }

    modifier checkTradeValue(uint256 _value) {
        require(msg.value == _value, "invalid value");
        _;
    }

    modifier checkTradeState(State _state, State state) {
        require(state == _state, "invalid state");
        _;
    }
}
