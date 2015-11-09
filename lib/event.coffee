"use strict"

Event = (irc, network) ->
  @irc = irc
  @network = network
  Object.defineProperty @, 'irc',
    enumerable: false
    writable: true
  return

module.exports = Event

Event::getMessage = ->
  @_message

Event::reply = (message) ->
  @_reply "send", message

Event::replyAction = (message) ->
  @_reply "action", message

Event::replyNotice = (message) ->
  @_reply "notice", message

Event::_reply = (action, message) ->
  if @channel or @user
    fn = @irc[action]
    if typeof fn is 'function'
      fn = fn.bind @irc
      if @channel
        return fn @channel
      else
        return fn @user, message, @network
  return
