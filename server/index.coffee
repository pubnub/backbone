_ = require('underscore')._
Backbone = require 'backbone'
unicaster = require './unicaster'
pubnub = require('pubnub').init
  publish_key: 'pub-c-6dd9f234-e11e-4345-92c4-f723de52df70'
  subscribe_key: 'sub-c-4c7f1748-ced1-11e2-a5be-02ee2ddab7fe'

Todo = Backbone.Model.extend
  defaults: () ->
    {
      title: "empty todo..."
      order: Todos.nextOrder()
      done: false
    }

  toggle: () ->
    @save
      done: !@get 'done'

TodoList = Backbone.Collection.extend
  model: Todo

  done: () ->
    @where { done: true }

  remaining: () ->
    @without.apply this, @done()

  remaining: () ->
    @without.apply this, @done()

  nextOrder: () ->
    if not @length then return 1
    @last().get('order') + 1

  comparator: 'order'

Todos = new TodoList

# Subscribe to the todo list updates
pubnub.subscribe
  channel: 'backbone-collection-TodoList'
  callback: (message) ->
    console.log message

    data = JSON.parse message

    if data.method is "create"
      Todos.add data.model
    else if data.method is "delete"
      Todos.remove data.model
    else if data.method is "update"
      unless not data.model.id
        record = _.find Todos.models, (record) ->
          record.id is data.model.id

        unless record?
          console.log "Could not record: #{model.id}"

        diff = _.difference _.keys(record.attributes), _.keys(data.model)
        _.each diff, (key) ->
          record.unset key

        record.set data.model, data.options

app = unicaster.listen pubnub

# Return the list of todos
app.on 'getTodos', (req, resp) ->
  resp.end Todos.toJSON()
