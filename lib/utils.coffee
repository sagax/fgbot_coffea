"use strict"
CoffeaEvent = require './event'
Message = require './parser/Message'

exports.channelList = (str) ->
  str.split(',').map (chan) ->
    chan.toLowerCase()

exports.nick = (msg) ->
  msg.prefix.split('!')[0]

exports.emit = (instance, network, event, data) ->
  if not data
    data = {}

  err = undefined

  if data instanceof Error
    err = data
    data = {}

  event_obj = new CoffeaEvent instance, network
  if data instanceof Message
    event_obj._message = data

  for key in data
    if data.hasOwnProperty key
      event_obj[key] = data[key]

  event_obj.name = event

  retErr = undefined
  if err
    retErr = instance.emit 'error', err, event_obj

  ret1 = instance.emit event, err, event_obj
  ret2 = instance.emit network + ':' + event, err, event_obj
  ret3 = instance.emit 'event', event, err, event_obj
  [ret1, ret2, ret3]

exports.toArray = (val) ->
  if Array.isArray val then val else [val]

exports.extractNetwork = (target) ->
  if typeof target.getNetwork is 'function'
    target.getNetwork()
  else
    return

exports.targetString = (target) ->
  if target.client
    if target.client.isUser target
      target.getNick()
    else if target.client.isChannel target
      target.getName()
    else
      target.toString()
  target

exports.parseTarget = (target_raw) ->
  target = undefined
  network = undefined
  if typeof target_raw isnt 'string'
    network = exports.extractNetwork target_raw
    target = exports.targetString target_raw
  else
    if target_raw.indexOf(':') > -1
      splits = target_raw.split ':'
      if splits.length > 1
        network = splits[0]
        target = splits[1]
    else
      target = target_raw

  network: network, target: target

exports.extend = (a, b) ->
  for prop in b
    if b.hasOwnProperty prop
      a[prop] = b[prop]

  a

exports.inherit = (childClass, parentClass) ->
  F = -> return
  F:: = parentClass.prototype
  F::constructor = F
  childClass.prototype = new F()

  childClass.prototype.constructor = childClass
  parentClass.prototype.constructor = parentClass

  childClass.prototype.parent = parentClass.prototype
  return

exports.stripMessage = (leading, msg, me, fn) ->
  maxlen = 512 - (1 + me.getNick().length + 1 + me.getUsername().length + 1 + me.getHostname().length + 1) - leading.length - 2

  msg.match(new RegExp('.{1,' + maxlen + '}', 'g')).forEach (str) ->
    if str[0] is ' '
      str = str.substring 1
    if str[str.length - 1] is ' '
      str = str.substring 0, (str.length - 1)
    fn str
    return
  return


STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
ARGUMENT_NAMES = /([^\s,]+)/g

exports.getParamNames = (func) ->
  fnStr = func.toString().replace STRIP_COMMENTS, ''
  result = fnStr.slice (fnStr.indexOf('(') + 1), fnStr.indexOf(')').match(ARGUMENT_NAMES)
  if result is null
    result = []
  result

exports.SSLError = (message) ->
  @name = 'SSLError'
  @message = message or 'SSL Connection Error'
  return

exports.SSLError.prototype = new Error()
exports.SSLError.prototype.constructor = exports.SSLError
