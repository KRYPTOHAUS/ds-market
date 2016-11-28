pragma solidity ^0.4.6;

import "dapple/test.sol";

import "DSMarket60.sol";

contract DSMarket60Test is Test,
    DSMarket60Events,
    DSMarket60Clock
{
    uint        lifetime  = 10 minutes;
    uint        _time     = 1500000000;
    DSMarket60  market;

    function setUp() {
        market = new DSMarket60(this, lifetime);
    }

    function time() constant returns (uint) {
        return _time;
    }

    function test_initial_state() {
        assertEq(market.offerCount(), 0);
        assertFalse(market.expired());
    }

    function testFail_make_zero_offer() {
        market.make(DSMarket60Token(0), DSMarket60Token(0), 0, 0);
    }

    function testFail_make_wrong_eth() {
        market.make(DSMarket60Token(0), DSMarket60Token(0x1234), 1, 1234);
    }

    function test_make_free_eth_offer() {
        expectEventsExact(market);

        LogMake(
            0,
            this,
            DSMarket60Token(0),
            DSMarket60Token(0x1234),
            1,
            1234
        );

        market.make.value(1)({
            _haveToken:  DSMarket60Token(0),
            _wantToken:  DSMarket60Token(0x1234),
            _haveAmount: 1,
            _wantAmount: 1234,
        });

        assertEq(market.maker(0), this);
        assertEq(market.haveToken(0), DSMarket60Token(0));
        assertEq(market.wantToken(0), DSMarket60Token(0x1234));
        assertEq(market.haveAmount(0), 1);
        assertEq(market.wantAmount(0), 1234);
    }

    // TODO: remaining tests
}
