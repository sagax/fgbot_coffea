/*jslint node: true, nomen: true*/
"use strict";

var _ = require('underscore');

var Channel = function (name, client, network) {
    this.name = name;
    this.client = client;
    this.network = network;
    this.topic = {};
    this.names = {};
};

Channel.prototype.toString = function () {
    return this.name;
};

Channel.prototype.getName = function () {
    return this.name;
};

Channel.prototype.getTopic = function () {
    return this.topic;
};

Channel.prototype.getNames = function () {
    return this.names; // {'nick': ['~']}
};

Channel.prototype.getNetwork = function () {
    return this.network;
};

Channel.prototype.userHasMode = function (user, mode) {
    user = typeof user === "string" ? user : user.getNick();
    if (this.names.hasOwnProperty(user)) {
        return this.names[user].indexOf(mode) > -1;
    }
    return false;
};

Channel.prototype.isUserInChannel = function (user) {
    user = typeof user === "string" ? user : user.getNick();
    return this.names.hasOwnProperty(user);
};

Channel.prototype.notice = function (msg) {
    this.client.notice(this.getName(), msg, this.network);
};

Channel.prototype.say = function (msg) {
    this.client.send(this.getName(), msg, this.network);
};

Channel.prototype.reply = function (user, msg) {
    user = typeof user === "string" ? user : user.getNick();
    this.say(user + ': ' + msg);
};

Channel.prototype.kick = function (user, reason) {
    user = typeof user === "string" ? user : user.getNick();
    this.client.kick(this.getName(), user, reason, this.network);
};

Channel.prototype._changeBan = function _changeBan(deleting, mask) {
    var mode;
    if (deleting) {
        mode = ' -b ';
    } else {
        mode = ' +b ';
    }
    this.client.write('MODE ' + this.getName() + mode + mask, this.network);
};

Channel.prototype.ban = function (mask) {
    this.changeBan(false, mask);
};

Channel.prototype.unban = function (mask) {
    this.changeBan(true, mask);
};

module.exports = function () {
    var channelCache = [],
        channelList = [];
    return function (irc) {

        irc.define('irc', 'getChannellist', function () {
            return channelList;
        });

        irc.define('irc', 'getChannel', function (name, network) {
            var channel = _.find(channelCache, function (chan) {
                if (network) { return (chan.getName() === name) && (chan.getNetwork() === network); }
                else { return chan.getName() === name; }
            });
            if (channel === undefined) {
                channel = new Channel(name, irc, network);
                channelCache.push(channel);
            }
            return channel;
        });

        irc.define('irc', 'isChannel', function (channel) {
            return channel instanceof Channel;
        });

        // add channel to list if we joined
        irc.on('join', function (err, event) {
            if (irc.isMe(event.user)) {
                channelList.push(event.channel.getName());
                channelList = _.uniq(channelList);
            }
        });

	// remove channel from list if we parted/got kicked
	function _removeChannel(err, event) {
	    if (irc.isMe(event.user)) {
	        channelList = _.without(channelList, event.channel.getName());
	    }
	}
        irc.on('part', _removeChannel);
        irc.on('kick', _removeChannel);
    };
};
