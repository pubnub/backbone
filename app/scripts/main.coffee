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

  localStorage: new Backbone.LocalStorage 'todos-backbone'

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
    @listenTo @model, 'destroy', @remove

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

    Todos.fetch()

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
    
