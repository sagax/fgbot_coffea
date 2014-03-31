/*jslint node: true*/
/*global describe, it*/
"use strict";

var irc = require('../..');
var Stream = require('stream').PassThrough;

describe('channel()', function () {
    describe('getChannel()', function () {
        it('should return Channel object', function (done) {
            var stream = new Stream(),
                client = irc(stream),
                channel = client.getChannel('#foo');

            channel.getName().should.equal('#foo');
            done();
        });
    });
    describe('isChannel()', function () {
        it('should return true', function (done) {
            var stream = new Stream(),
                client = irc(stream),
                channel = client.getChannel('#foo');

            client.isChannel(channel).should.equal(true);
            done();
        });
        it('should return false', function (done) {
            var stream = new Stream(),
                client = irc(stream);

            client.isChannel(undefined).should.equal(false);
            done();
        });
    });
    describe('getChannellist()', function () {
        it('should return List of channels that we are in', function (done) {
            var stream = new Stream(),
                client = irc(stream),
                chanlist;
            client.nick('foo');


            stream.write(':foo!bar@baz.com JOIN :#foo\r\n');
            stream.write(':foo!bar@baz.com JOIN :#bar\r\n');
            stream.write(':foo!bar@baz.com JOIN :#baz\r\n');
            stream.write(':foo!bar@baz.com PART #bar :So long!\r\n');
            process.nextTick(function () {
                chanlist = client.getChannellist();
                chanlist.should.be.instanceof(Array).and.have.lengthOf(2);
                chanlist[0].should.equal('#foo');
                chanlist[1].should.equal('#baz');
                done();
            });
        });
    });
});