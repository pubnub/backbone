_ = require 'underscore'
pubnub = require('pubnub').init
  publish_key: 'pub-c-6dd9f234-e11e-4345-92c4-f723de52df70'
  subscribe_key: 'sub-c-4c7f1748-ced1-11e2-a5be-02ee2ddab7fe'

todos = []

# Subscribe to the todo list updates
pubnub.subscribe
  channel: 'backbone-collection-TodoList'
  callback: (message) ->
    console.log message
