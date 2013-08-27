################
# Backbone.PubNub
# -----------------
# The Backbone.PubNub object is used as a plugin to make collections real-time
################
Backbone.PubNub = (ref, name) ->
  @name = name
  @ref = ref
  @uuid = @ref.uuid()
  @channel = "backbone-#{@name}"
  @records = []

  # Subscribe to publish methods and react to what happens on the other side
  @ref.subscribe
    channel: @channel
    callback: (message) =>
      message = JSON.parse message

      # We don't want to cause a loop by listening to our own events
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

  # Finds a model in the local array
  read: (model) ->
    unless model.id?
      @find model.id
    else
      @findAll()

  # Find an individual record
  find: (id) ->
    _.find @records, (record) ->
      record.id is id

  # Return all records from the local array
  findAll: () ->
    @records

  # Create a new record and publish it to other instances
  create: (model) ->
    unless model.id?
      model.id = @ref.uuid()
      model.set model.idAttribute, model.id

    @records.push model
    @publish "create", model
    model

  # When a record updates, publish the changes to other instances
  update: (model) ->
    oldModel = @find model.id
    @records[@records.indexOf(oldModel)] = model
    @publish "update", model
    model

  # When a record is removed, publish the changes to other instances
  destroy: (model) ->
    if model.isNew()
      return false
    @records = _.reject @records, (record) ->
      record.id is model.id
    @publish "delete", model
    model

# Custom sync method for using the plugin version
Backbone.PubNub.sync = (method, model, options) ->
  pubnub = model.pubnub ? model.collection.pubnub

  console.log method, model, options, pubnub

  try
    switch method
      when "read" then resp = pubnub.read model
      when "create" then resp = pubnub.create model
      when "update" then resp = pubnub.update model
      when "delete" then resp = pubnub.destroy model
  catch error
    errorMessage = error.message
    console.log "Could not sync: #{errorMessage}"

# Save the old sync method for later use
_sync = Backbone.sync

# Override the sync method to use pubnub if it is available
Backbone.sync = (method, model, options) ->
  syncMethod = _sync

  if model.pubnub or (model.collection and model.collection.pubnub)
    syncMethod = Backbone.PubNub.sync

  syncMethod.apply this, [method, model, options]

################
# Backbone.PubNub.Collection
# ----------------------------
# A real-time implementation of a Backbone Collection.
# This works by publishing a transaction of all methods (create, update, delete)
# to other instances.
################
Backbone.PubNub.Collection = Backbone.Collection.extend
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

  constructor: (models, options) ->
    Backbone.Collection.apply this, arguments

    if options and options.pubnub
      @pubnub = options.pubnub

    @uuid = @pubnub.uuid()
    @channel = "backbone-collection-#{@name}"

    # Subscribe to this colleciton's channel and listen for changes to
    # other client's collections
    @pubnub.subscribe
      channel: @channel
      callback: (message) =>
        message = JSON.parse message

        unless message.uuid is @uuid
          switch message.method
            when "create" then @_onAdded message.model, message.options
            when "update" then @_onChanged message.model, message.options
            when "delete" then @_onRemoved message.model, message.options

    # When the collection changes we post updates to everyone else
    updateModel = (model) ->
      @publish "update", model
    @listenTo this, 'change', updateModel, this

  # Called when another client adds a record
  _onAdded: (model, options) ->
    Backbone.Collection.prototype.add.apply this, [model, options]

  # Called when another client changes a record
  _onChanged: (model, options) ->
    unless not model.id
      record = _.find @models, (record) ->
        record.id is model.id

      unless record?
        console.log "Could not find model with ID: #{model.id}"
        return false

      # Since there is no native update record we have to find the differences manually
      diff = _.difference _.keys(record.attributes), _.keys(model)
      _.each diff, (key) ->
        record.unset key

      record.set model, options

  # Called when another client removes a record
  _onRemoved: (model, options) ->
    Backbone.Collection.prototype.remove.apply this, [model, options]

  add: (models, options) ->
    models = if _.isArray(models) then models.slice() else [models]

    for model in models
      # We need to manually create an ID for each record, otherwise
      # Backbone will not give us change or remove events
      unless model.id?
        model.id = @pubnub.uuid()

      @publish "create", model, options

    Backbone.Collection.prototype.add.apply this, arguments

  remove: (models, options) ->
    models = if _.isArray(models) then models.slice() else [models]

    for model in models
      @publish "delete", model, options

    Backbone.Collection.prototype.remove.apply this, arguments

################
# Backbone.PubNub.Model
# ----------------------------
# A real-time implementation of a Backbone Model.
# This will publish all change events to other instances of the same model. It
# will also remove itself if another instance is removed
################
Backbone.PubNub.Model = Backbone.Model.extend
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

    @on 'change', @_onChange, this

    # Subscribe to updates from other instances of this model
    @pubnub.subscribe
      channel: @channel
      callback: (message) =>
        message = JSON.parse message

        unless message.uuid is @uuid
          switch message.method
            when "update" then @_onChanged message.model, message.options
            when "delete" then @_onRemoved message.options

  # Publish changes when this model is changed
  _onChange: (model, options) ->
    @publish "update", model, options

  _onChanged: (model, options) ->
    @off 'change', @_onChange, this
    # Manually find the difference and update this model
    diff = _.difference _.keys(@attributes), _.keys(model)
    _.each diff, (key) =>
      @unset key

    @set model
    @on 'change', @_onChange, this

  _onRemoved: (options) ->
    Backbone.Model.prototype.destroy.apply this, arguments

  destroy: (options) ->
    @publish "delete", null, options
    Backbone.Model.prototype.destroy.apply this, arguments