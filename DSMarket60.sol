/// DSMarket60.sol -- trustless hybrid ETH/ERC20 market

// Copyright 2016  Nexus Development, LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy of the License may be obtained at the following URL:
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

pragma solidity ^0.4.6;

contract DSMarket60Events {
    event LogMake(
        uint              id,
        address  indexed  maker,
        address  indexed  haveToken,
        address  indexed  wantToken,
        uint              haveAmount,
        uint              wantAmount
    );

    event LogTake(
        uint              id,
        address  indexed  maker,
        address  indexed  haveToken,
        address  indexed  wantToken,
        address           taker,
        uint              takeAmount,
        uint              giveAmount
    );

    event LogCancel(
        uint              id,
        address  indexed  maker,
        address  indexed  haveToken,
        address  indexed  wantToken
    );
}

contract DSMarket60Clock {
    function time() constant returns (uint);
}

contract DSMarket60Token {
    function transfer(
        address  recipient,
        uint     amount
    ) returns (bool);

    function transferFrom(
        address  owner,
        address  recipient,
        uint     amount
    ) returns (bool);
}

contract DSMarket60 is DSMarket60Events {
    DSMarket60Clock  public  clock;
    uint             public  openingTime;
    uint             public  closingTime;

    function DSMarket60(DSMarket60Clock _clock, uint lifetime) {
        clock       = _clock;
        openingTime = time();
        closingTime = openingTime + lifetime;
    }

    function time() constant returns (uint) {
        return clock == address(0) ? now : clock.time();
    }

    function expired() constant returns (bool) {
        return time() >= closingTime;
    }

    function offerCount() constant returns (uint) {
        return maker.length;
    }

    address[]           public  maker;
    DSMarket60Token[]   public  haveToken;
    DSMarket60Token[]   public  wantToken;
    uint[]              public  haveAmount;
    uint[]              public  wantAmount;

    function make(
        DSMarket60Token  _haveToken,
        DSMarket60Token  _wantToken,
        uint             _haveAmount,
        uint             _wantAmount
    ) payable returns (uint id) {
        assert(!expired());
        assert(_haveAmount > 0);
        assert(_haveAmount < 2**127);
        assert(_wantAmount < 2**127);

        id = offerCount();

        maker      .push(msg.sender);
        haveToken  .push(_haveToken);
        wantToken  .push(_wantToken);
        haveAmount .push(_haveAmount);
        wantAmount .push(_wantAmount);

        if (_haveToken == address(0)) {
            assert(msg.value == _haveAmount);
        } else {
            assert(msg.value == 0);
            assert(_haveToken.transferFrom(msg.sender, this, _haveAmount));
        }

        LogMake(
            id,
            msg.sender,
            _haveToken,
            _wantToken,
            _haveAmount,
            _wantAmount
        );
    }

    function take(uint id, uint maxTakeAmount) payable {
        assert(!expired());
        assert(maxTakeAmount > 0);
        assert(maxTakeAmount <= haveAmount[id]);

        uint giveAmount = wantAmount[id] * maxTakeAmount / haveAmount[id];
        uint takeAmount = haveAmount[id] * giveAmount / wantAmount[id];

        haveAmount[id] -= takeAmount;
        wantAmount[id] -= giveAmount;

        if (wantToken[id] == DSMarket60Token(0)) {
            assert(msg.value == giveAmount);
            assert(maker[id].send(msg.value));
        } else {
            assert(wantToken[id].transferFrom(
                msg.sender, maker[id], giveAmount
            ));
        }

        if (haveToken[id] == DSMarket60Token(0)) {
            assert(msg.sender.send(takeAmount));
        } else {
            assert(haveToken[id].transfer(msg.sender, takeAmount));
        }

        LogTake(
            id,
            maker[id],
            haveToken[id],
            wantToken[id],
            msg.sender,
            takeAmount,
            giveAmount
        );

        if (haveAmount[id] == 0) {
            erase(id);
        }
    }

    function take(uint id) payable {
        take(id, haveAmount[id]);
    }

    function cancel(uint id) {
        assert(maker[id] == msg.sender);

        DSMarket60Token  _haveToken   = haveToken[id];
        uint             _haveAmount  = haveAmount[id];
        DSMarket60Token  _wantToken   = wantToken[id];

        erase(id);

        if (_haveToken == DSMarket60Token(0)) {
            assert(msg.sender.send(_haveAmount));
        } else {
            assert(_haveToken.transfer(msg.sender, _haveAmount));
        }

        LogCancel(id, msg.sender, _haveToken, _wantToken);
    }

    function erase(uint id) internal {
        delete  maker       [id];
        delete  haveToken   [id];
        delete  wantToken   [id];
        delete  haveAmount  [id];
        delete  wantAmount  [id];
    }

    function assert(bool condition) {
        if (!condition) {
            throw;
        }
    }
}
