# Start by creating our PubNub instance
uuid = PUBNUB.uuid()
pubnub = PUBNUB.init
  subscribe_key: 'sub-c-4c7f1748-ced1-11e2-a5be-02ee2ddab7fe'
  publish_key: 'pub-c-6dd9f234-e11e-4345-92c4-f723de52df70'
  uuid: uuid

Todo = Backbone.Model.extend
  defaults: () ->
    {
      title: "empty todo..."
      order: Todos.nextOrder()
      done: false
    }

  toggle: () ->
    @set
      done: !@get 'done'

TodoList = Backbone.PubNub.Collection.extend
  model: Todo

  name: "TodoList"    # The name tells us what PubNub channel to use
  pubnub: pubnub      # Pass in our global PubNub instance

  constructor: () ->
    Backbone.PubNub.Collection.apply this, arguments

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
    @listenTo @model, 'remove', @remove

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
      @model.set { title: value }
      @$el.removeClass 'editing'

  updateOnEnter: (event) ->
    if event.keyCode is 13 then @close()

  clear: () ->
    Todos.remove @model

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

    Todos.add { title: @input.val() }
    @input.val ''

  clearCompleted: () ->
    _.each Todos.done(), (model) ->
      Todos.remove model
    false

  toggleAllCompleted: () ->
    done = @allCheckbox.checked
    Todos.each (todo) ->
      todo.set { 'done': done }

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

  initialize: () ->
    @listenTo mymodel, 'all', @render

    @render()

  onUpdateClick: (event) ->
    mymodel.set
      rand: Math.random()

  render: () ->
    @$el.html @template(mymodel.toJSON())

modelview = new MyModelView

# Initially get the list of todos from the server
pubnub.subscribe
  channel: uuid
  callback: (message) ->
    data = message
    Todos.set data
  connect: () ->
    pubnub.publish
      channel: 'getTodos'
      message:
        uuid: uuid

# Mixpanel Tracking
mixpanel.track_links '#github', 'GitHub repo click',
  repository: 'pubnub/backbone'

mixpanel.track_links '#get-started', 'Get started click',
  repository: 'pubnub/backbone',
  type: 'Call To Action'