pubnub = PUBNUB.init
  subscribe_key: 'sub-c-4c7f1748-ced1-11e2-a5be-02ee2ddab7fe'
  publish_key: 'pub-c-6dd9f234-e11e-4345-92c4-f723de52df70'

@pubnub = pubnub

Backbone.PubNub = (ref, name) ->
  @name = name
  @ref = ref
  @uuid = @ref.uuid()
  @channel = "backbone-#{@name}"
  @records = []

  @ref.subscribe
    channel: @channel
    callback: (message) =>
      message = JSON.parse message

      unless message.uuid is @uuid
        switch message.method
          when "create" then @create message.model
          when "update" then @update message.model
          when "delete" then @destroy message.model

_.extend Backbone.PubNub.prototype,
  # Publishes a change to the pubnub channel
  publish: (method, model, options) ->
    message =
      method: method
      model: model
      options: options
      uuid: @uuid
    message = JSON.stringify message

    @ref.publish
      channel: @channel
      message: message

  read: (model) ->
    unless model.id?
      @find model.id
    else
      @findAll()

  find: (id) ->
    _.find @records, (record) ->
      record.id is id

  findAll: () ->
    @records

  create: (model) ->
    unless model.id?
      model.id = @ref.uuid()
      model.set model.idAttribute, model.id

    @records.push model
    @publish "create", model
    model

  update: (model) ->
    oldModel = @find model.id
    @records[@records.indexOf(oldModel)] = model
    @publish "update", model
    model

  destroy: (model) ->
    if model.isNew()
      return false
    @records = _.reject @records, (record) ->
      record.id is model.id
    @publish "delete", model
    model

Backbone.PubNub.sync = (method, model, options) ->
  pubnub = model.pubnub ? model.collection.pubnub

  try
    switch method
      when "read" then resp = pubnub.read model
      when "create" then resp = pubnub.create model
      when "update" then resp = pubnub.update model
      when "delete" then resp = pubnub.destroy model
  catch error
    errorMessage = error.message
    console.log "ERROR", error

_sync = Backbone.sync

Backbone.sync = (method, model, options) ->
  syncMethod = _sync

  if model.pubnub or (model.collection and model.collection.pubnub)
    syncMethod = Backbone.PubNub.sync

  syncMethod.apply this, [method, model, options]

Backbone.PubNub.Collection = Backbone.Collection.extend
  sync: () ->
    console.log "Backbone.PubNub.Collection ignores sync calls"

  fetch: () ->
    console.log "Backbone.PubNub.Collection ignores fetch calls"

  # Publishes a change to the pubnub channel
  publish: (method, model, options) ->
    message =
      method: method
      model: model
      options: options
      uuid: @uuid
    message = JSON.stringify message

    console.log "PUBLISH", message

    @pubnub.publish
      channel: @channel
      message: message

  constructor: (models, options) ->
    Backbone.Collection.apply this, arguments

    if options and options.pubnub
      @pubnub = options.pubnub

    @uuid = @pubnub.uuid()
    @channel = "backbone-collection-#{@name}"

    updateModel = (model) ->
      @publish "update", model

    @listenTo this, 'change', updateModel, this

    @pubnub.subscribe
      channel: @channel
      callback: (message) =>
        message = JSON.parse message

        unless message.uuid is @uuid
          switch message.method
            when "create" then @_onAdded message.model, message.options
            when "update" then @_onChanged message.model, message.options
            when "delete" then @_onRemoved message.model, message.options

  _onAdded: (model, options) ->
    Backbone.Collection.prototype.add.apply this, [model, options]

  _onChanged: (model, options) ->
    unless not model.id
      record = _.find @models, (record) ->
        record.id is model.id

      unless record?
        throw new Error "Could not find model with ID: #{model.id}"

      diff = _.difference _.keys(record.attributes), _.keys(model)
      _.each diff, (key) ->
        record.unset key

      record.set model, options

  _onRemoved: (model, options) ->
    Backbone.Collection.prototype.remove.apply this, [model, options]

  add: (models, options) ->
    models = if _.isArray(models) then models.slice() else [models]

    for model in models
      unless model.id?
        model.id = @pubnub.uuid()
        model.set model.idAttribute, model.id

      @publish "create", model, options

    Backbone.Collection.prototype.add.apply this, arguments

  remove: (models, options) ->
    models = if _.isArray(models) then models.slice() else [models]

    for model in models
      @publish "delete", model, options

    Backbone.Collection.prototype.remove.apply this, arguments

Backbone.PubNub.Model = Backbone.Model.extend
  sync: () ->
    console.log "Backbone.PubNub.Model ignores sync calls"

  # Publishes a change to the pubnub channel
  publish: (method, model, options) ->
    message =
      method: method
      model: model
      options: options
      uuid: @uuid
    message = JSON.stringify message

    @pubnub.publish
      channel: @channel
      message: message

  constructor: (model, options) ->
    Backbone.Model.apply this, arguments

    if options and options.pubnub and options.name
      @pubnub = options.pubnub
      @name = options.name

    @uuid = @pubnub.uuid()
    @channel = "backbone-model-#{@name}"

    updateModel = (model, options) ->
      @publish "update", model, options

    @listenTo this, 'change', updateModel, this

    @pubnub.subscribe
      channel: @channel
      callback: (message) =>
        message = JSON.parse message

        unless message.uuid is @uuid
          switch message.method
            when "update" then @_onChanged message.model, message.options
            when "delete" then @_onRemoved message.options

  _onChanged: (model, options) ->
    diff = _.difference _.keys(@attributes), _.keys(model)
    _.each diff, (key) =>
      @unset key

    @set model

  _onRemoved: (options) ->
    Backbone.Model.prototype.destroy.apply this, arguments

  destroy: (options) ->
    @publish "delete", null, options
    Backbone.Model.prototype.destroy.apply this, arguments

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

TodoList = Backbone.PubNub.Collection.extend
  model: Todo

  name: "TodoList"
  pubnub: pubnub

  constructor: () ->
    Backbone.PubNub.Collection.apply this, arguments

    @listenTo this, 'remove', (model) ->
      model.destroy()

  done: () ->
    @where { done: true }

  remaining: () ->
    @without.apply this, @done()

  nextOrder: () ->
    if not @length then return 1
    @last().get('order') + 1

  comparator: 'order'

Todos = new TodoList

TodoView = Backbone.View.extend
  tagName: 'li'

  template: _.template($('#item-template').html())

  events:
    'click .toggle': 'toggleDone'
    'dblclick .view': 'edit'
    'click a.destroy': 'clear'
    'keypress .edit': 'updateOnEnter'
    'blur .edit': 'close'

  initialize: () ->
    @listenTo @model, 'change', @render
    @listenTo @model, 'destroy', () =>
      console.log "REMOVING"
      @remove()

  render: () ->
    @$el.html @template @model.toJSON()
    @$el.toggleClass 'done', @model.get('done')
    @input = @$ '.edit'
    this

  toggleDone: () ->
    @model.toggle()

  edit: () ->
    @$el.addClass 'editing'
    @input.focus()

  close: () ->
    value = @input.val()

    if not value
      @clear()
    else
      @model.save { title: value }
      @$el.removeClass 'editing'

  updateOnEnter: (event) ->
    if event.keyCode is 13 then @close()

  clear: () ->
    @model.destroy()

AppView = Backbone.View.extend
  el: $ '#todoapp'

  statsTemplate: _.template($('#stats-template').html())

  events:
    'keypress #new-todo': 'createOnEnter'
    'click #clear-completed': 'clearCompleted'
    'click #toggle-all': 'toggleAllCompleted'

  initialize: () ->
    @input = @$ '#new-todo'
    @allCheckbox = @$('#toggle-all')[0]

    @listenTo Todos, 'add', @addOne
    @listenTo Todos, 'reset', @addAll
    @listenTo Todos, 'all', @render

    @footer = @$ 'footer'
    @main = $ '#main'

  render: () ->
    done = Todos.done().length
    remaining = Todos.remaining().length

    if Todos.length
      @main.show()
      @footer.show()
      @footer.html @statsTemplate { done: done, remaining: remaining }
    else
      @main.hide()
      @footer.hide()

    @allCheckbox.checked = !remaining

  addOne: (todo) ->
    view = new TodoView { model: todo }
    @$('#todo-list').append view.render().el

  addAll: () ->
    Todos.each @addOne, this

  createOnEnter: (event) ->
    if event.keyCode isnt 13 then return
    if not @input.val() then return

    Todos.create { title: @input.val() }
    @input.val ''

  clearCompleted: () ->
    _.invoke Todos.done(), 'destroy'
    false

  toggleAllCompleted: () ->
    done = @allCheckbox.checked
    Todos.each (todo) ->
      todo.save { 'done': done }

App = new AppView
    

MyModel = Backbone.PubNub.Model.extend
  name: "MyModel"
  pubnub: pubnub

  defaults: () ->
    {
      rand: Math.random()
      title: "My Model"
    }

mymodel = new MyModel

MyModelView = Backbone.View.extend
  el: $ '#mymodel'

  template: _.template($('#mymodel-template').html())

  events:
    'click #update': 'onUpdateClick'
    'click #delete': 'onDeleteClick'

  initialize: () ->
    @listenTo mymodel, 'destroy', @render
    @listenTo mymodel, 'all', @render

    @render()

  onUpdateClick: (event) ->
    mymodel.set
      rand: Math.random()

  onDeleteClick: (event) ->
    mymodel.destroy()

  render: () ->
    @$el.html @template(mymodel.toJSON())

modelview = new MyModelView
