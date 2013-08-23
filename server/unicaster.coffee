class Request
  constructor: (@type, @params) ->
    # Placeholder

class Response
  constructor: (@pubnub, @type, @uuid) ->
    # Placeholder

  end: (message) ->
    unless not @uuid?
      @pubnub.publish
        channel: @uuid
        message: message

class Unicaster
  constructor: (@pubnub) ->
    @listeners = {}

  _dispatch: (type, data) ->
    unless not @listeners[type]?
      req = new Request type, data
      resp = new Response @pubnub, type, data.uuid
      @listeners[type](req, resp)

  on: (type, callback) ->
    @listeners[type] = callback

    @pubnub.subscribe
      channel: type
      callback: (data) =>
        @_dispatch(type, data)

module.exports =
  listen: (pubnub) ->
    new Unicaster pubnub
