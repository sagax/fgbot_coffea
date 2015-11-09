"use strict"

EventEmitter   = require 'eventemitter3'
Parser         = require './lib/parser'
net            = require 'net'
tls            = require 'tls'
fs             = require 'fs'
replies        = require 'irc-replies'
stream_module  = require 'stream'
StreamReadable = stream_module.Readable
StreamWritable = stream_module.Writable
utils          = require './lib/utils'
RateLimiter    = require('limiter').RateLimiter

Client = (info, throttling) ->
  unless this instanceof Client
    new Client info, throttling

  try
    pkg = require './package.json'
    version = pkg.version
    return
  catch err
    return

  @streams = {}
  @settings = {}
  @stinfo = {}
  @networked_me = {}
  @capabilities = []

  @_loadPlugins()

  if typeof info is 'boolean'
    throttling = info
    info = null
  
  @throttling = throttling if throttling isnt undefined

  @add(info) if info

  return

module.exports = Client

utils.inherit Client, EventEmitter

Client::splitString = (text) ->
  message = text.match /[^\s"']+|"([^"]*)"|'([^']*)'/g
  message = message && message.map (m) ->
    if ((m.charAt(0) is '"') and (m.charAt(m.length - 1) is '"')) or ((m.charAt(0) is '\'') or (m.charAt(m.length - 1) is '\''))
      m.substring(1, m.length - 1).split('\\').join("")
    else
      m
  return

Client::_loadPlugins = ->
  _this = @
  files = fs.readdirSync __dirname + '/lib/plugins/'
  files.forEach (file) ->
    if file.substr(-3, 3) is '.js'
      _this.use require(__dirname + '/lib/plugins/' + file)()
    return
  return

Client::_check = (network) ->
  ret = {}
  randnick = "coffea" + Math.floor(Math.random() * 100000)
  if typeof network is 'string'
    ret.host = network
  else
    ret.host = (if network.host is undefined then null else network.host)

  ret.name = network.name

  ret.nick = (if network.nick is undefined then randnick else network.nick)
  port = (if network.ssl is true then 6697 else 6667)
  ret.port = parseInt( if network.port is undefined then port else network.port )
  ret.ssl = (if network.ssl is undefined then (ret.port is 6697) else network.ssl)
  ret.ssl_allow_invalid = (if network.ssl_allow_invalid is undefined then false else network.ssl_allow_invalid)
  ret.username = (if network.username is undefined then ret.nick else network.username)
  ret.realname = (if network.realname is undefined then ret.nick else network.realname)
  ret.pass = network.pass

  ret.prefix = (if network.prefix is undefined then '!' else network.prefix)

  ret.channels = (if network.channels is undefined then ret.channels else network.channels)

  ret.throttling = network.throttling

  ret.sasl = (if network.sasl is undefined then null else networks.nickserv)

  ret

Client::_useStream = (stream, network, throttling, info) ->
  if network
    stream.coffea_id = network
  else
    stream.coffea_id = Object.keys(@streams).length.toString()

  stream.setEncoding 'utf8'
  throttling = (if throttling is undefined then @throttling else throttling)

  stream.limiter new RateLimiter(1, (if typeof throttling is 'number' then throttling else 250), throttling is false)

  parser = new Parser()
  _this = @
  parser.on 'message', (msg) ->
    _this.onmessage msg, stream.coffea_id

  parser.on 'end', ->
    utils.emit _this, stream.coffea_id, 'disconnect', {}

  stream.pipe parser

  @streams[stream.coffea_id] = stream
  @settings[stream.coffea_id] = {}

  stream.coffea_id

Client::useStream = (stream, network) ->
  @_useStream stream, network, network.throttling, network
  return

Client::reconnect = (stream_id) ->
  info = @stinfo[stream_id]
  stream = (if info.ssl then tls.connect(
    host: info.host
    port: info.port
  ) else (
    host: info.host
    port: info.port
  ))
  return

Client::_emitConnect = (network) ->
  utils.emit @, network, 'connect', null
  return

Client::_setupSASL = (stream_id, info) ->
  @on 'cap_ack', (err, event) ->
    if event.capabilities is 'sasl'
      @sasl.mechanism 'PLAIN', stream_id
      if info.sasl and info.sasl.account and info.sasl.password
        @sasl.login info.sasl.account, info.sasl.password, stream_id
      else if info.sasl and info.sasl.password
        @sasl.login info.username, info.sasl.password, stream_id
      else
        @sasl.login null, null, stream_id
    return
  return

Client::_connect = (stream_id, info) ->
  @_setupSASL stream_id, info
  if info.pass
    @pass info.pass
  @capReq [
    'account-notify'
    'away-notify'
    'extended-join'
    'sasl'
  ], stream_id
  @capEnd stream_id
  @nick info.nick, stream_id
  @user info.username, info.realname, stream_id
  if info.nickserv and info.nickserv.username and info.nickserv.password
    @identify info.nickserv.username, info.nickserv.password, stream_id
  else if info.nickserv and info.nickserv.password
    @identify info.nickserv.password, stream_id

  if info.channels
    @on 'motd', defaultOnMotd (err, event) ->
      @join info.channels, stream_id
      return
  return

Client::add = (info) ->
  stream = undefined
  stream_id = undefined
  streams = []
  _this = @
  if info.instanceof Array
    info.forEach (network) ->
      stream = undefined
      network = _this._check network
      if network.ssl
        stream = tls.connect
          host: network.host
          port: network.port
          rejectUnauthorized: !network.ssl_allow_invalid
          , ->
            stream_id = _this._useStream stream, network.name, network.throttling, network
            utils.emit _this, stream_id, 'ssl-error', new utils.SSLError stream.authorizationError
            _this._connect stream_id, network
            streams.push stream_id
            _this._emitConnect stream_id
            return
      else
        stream = net.connect
          host: network.host
          port: network.port
          , ->
            stream_id = _this._useStream stream, network.name, network.throttling, network
            _this._connect stream_id, network
            streams.push stream_id
            _this._emitConnect stream_id
            return
      return
  else if (typeof info is 'string') or (info instanceof Object and (info not instanceof StreamReadable) and (info not StreamReadable))
    info = _this._check info
    if info.ssl
      stream = tls.connect
        host: info.host
        port: info.port
        rejectUnauthorized: !info.ssl_allow_invalid
        , ->
          stream_id = _this._useStream stream, info.name, info.throttling, info
          utils.emit _this, stream_id, 'ssl-error', new utils.SSLError stream.authorizationError
          _this._connect stream_id, info
          _this._emitConnect stream_id
          return
    else
      stream = net.connect
        host: info.host
        port: info.port
        , ->
          stream_id = _this._useStream stream, info.name, info.throttling, info
          _this._connect stream_id, info
          _this._emitConnect stream_id
          return
  else
    stream_id = @_useStream info, null, info.throttling, info

  if streams.length is 0
    stream_id
  else
    streams
  return

Client::write = (str, network, fn) ->
  if typeof network is 'function'
    fn = network
    network = undefined

  if network isnt null and typeof network is 'object'
    network = network.coffea_id

  _this = @
  if network and @streams.hasOwnProperty network
    _this.streams[network].write str + '\r\n', fn
  else
    for id in @streams
      if @streams.hasOwnProperty id
        @write str, id
    if fn
      fn()
  return

Client::use = (fn) ->
  fn @
  @

Client::fallbackCallback = (extended, event, fn, context) ->
  params = utils.getParamNames fn
  func = fn
  if params.length is 1
    func = (err, event) ->
      fn event, err
      return
  extend.call @, event, func, context
  return

Client::on = (event, fn, context) ->
  @fallbackCallback @parent.on, event, fn, context
  return

Client::once = (event, fn, context) ->
  @fallbackCallback @parent.once, event, fn, context
  return
