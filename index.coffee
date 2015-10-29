"use strict"

EventEmitter   = require 'eventemitter3'
Parser         = require './lib/parser'
net            = require 'net'
tls            = require 'tls'
fs             = require 'fs'
replies        = require 'irc-replies'
StreamReadable = require('stream').Readable
StreamWritable = require('stream').Writable
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


