scoring = require './scoring'
h = require './helpers'
_ = require 'underscore'
moment = require 'moment'
character = require './character'

module.exports.app = (appExports, model) ->
  user = model.at('_user')

  appExports.addTask = (e, el) ->
    type = $(el).attr('data-task-type')
    newModel = model.at('_new' + type.charAt(0).toUpperCase() + type.slice(1))
    text = newModel.get()
    # Don't add a blank task; 20/02/13 Added a check for undefined value, more at issue #463 -lancemanfv
    return if /^(\s)*$/.test(text) || text == undefined

    newTask = {id: model.id(), type: type, text: text, notes: '', value: 0}
    switch type
      when 'habit'
        newTask = _.defaults {up: true, down: true}, newTask
      when 'reward'
        newTask = _.defaults {value: 20 }, newTask
      when 'daily'
        newTask = _.defaults {repeat:{su:true,m:true,t:true,w:true,th:true,f:true,s:true}, completed: false }, newTask
      when 'todo'
        newTask = _.defaults {completed: false }, newTask
    model.unshift "_user.#{type}s", newTask
    newModel.set ''


  appExports.del = (e, el) ->
    # Derby extends model.at to support creation from DOM nodes
    task = e.get()

    history = task.history
    if history and history.length>2
      # prevent delete-and-recreate hack on red tasks
      if task.value < 0
        result = confirm("Are you sure? Deleting this task will hurt you (to prevent deleting, then re-creating red tasks).")
        if result != true
          return # Cancel. Don't delete, don't hurt user
        else
          task.set('type','habit') # hack to make sure it hits HP, instead of performing "undo checkbox"
          scoring.score(model, task, direction:'down')

        # prevent accidently deleting long-standing tasks
      else
        result = confirm("Are you sure you want to delete this task?")
        return if result != true

    $('[rel=tooltip]').tooltip('hide')

    e.at().del()

  appExports.clearCompleted = (e, el) ->
    completedIds =  _.pluck( _.where(model.get('_todoList'), {completed:true}), 'id')
    todoIds = user.get('todoIds')

    _.each completedIds, (id) -> user.del "tasks.#{id}"
    user.set 'todoIds', _.difference(todoIds, completedIds)

  appExports.toggleDay = (e, el) ->
    task = model.at(e.target)
    if /active/.test($(el).attr('class')) # previous state, not current
      task.set('repeat.' + $(el).attr('data-day'), false)
    else
      task.set('repeat.' + $(el).attr('data-day'), true)

  appExports.toggleTaskEdit = (e, el) ->
    hideId = $(el).attr('data-hide-id')
    toggleId = $(el).attr('data-toggle-id')
    $(document.getElementById(hideId)).addClass('visuallyhidden')
    $(document.getElementById(toggleId)).toggleClass('visuallyhidden')

  appExports.toggleChart = (e, el) ->
    hideSelector = $(el).attr('data-hide-id')
    chartSelector = $(el).attr('data-toggle-id')
    historyPath = $(el).attr('data-history-path')
    $(document.getElementById(hideSelector)).hide()
    $(document.getElementById(chartSelector)).toggle()

    matrix = [['Date', 'Score']]
    for obj in model.get(historyPath)
      date = +new Date(obj.date)
      readableDate = moment(date).format('MM/DD')
      matrix.push [ readableDate, obj.value ]
    data = google.visualization.arrayToDataTable matrix

    options = {
      title: 'History'
      backgroundColor: { fill:'transparent' }
    }

    chart = new google.visualization.LineChart(document.getElementById( chartSelector ))
    chart.draw(data, options)

  appExports.changeContext = (e, el) ->
    # Get the data from the element
    targetSelector = $(el).attr('data-target')
    newContext = $(el).attr('data-context')
    newActiveNav = $(el).parent('li')

    # If the clicked nav is already active, do nothing
    if newActiveNav.hasClass('active')
      return

    # Find the old active nav and context
    oldActiveNav = $(el).closest('ul').find('> .active')
    oldContext = oldActiveNav.find('a').attr('data-context')

    # Set the new active nav
    oldActiveNav.removeClass('active')
    newActiveNav.addClass('active')

    # Set the new context on the target
    target = $(targetSelector)
    target.removeClass(oldContext)
    target.addClass(newContext)


  setUndo = (stats, task) ->
    previousUndo = model.get('_undo')
    clearTimeout(previousUndo.timeoutId) if previousUndo?.timeoutId
    timeoutId = setTimeout (-> model.del('_undo')), 10000
    model.set '_undo', {stats:stats, task:task, timeoutId: timeoutId}


  ###
    Call scoring functions for habits & rewards (todos & dailies handled below)
  ###
  appExports.score = (e, el) ->
    task= model.at $(el).parents('li')[0]
    taskObj = task.get()
    direction = $(el).attr('data-direction')

    # set previous state for undo
    setUndo _.clone(user.get('stats')), _.clone(taskObj)

    scoring.score(model, taskObj, direction)

  ###
    This is how we handle appExports.score for todos & dailies. Due to Derby's special handling of `checked={:task.completd}`,
    the above function doesn't work so we need a listener here
  ###
  completedCallback = (i, completed, previous, isLocal, passed, type) ->
    return if passed? && passed.cron # Don't do this stuff on cron
    direction = if completed then 'up' else 'down'

    # set previous state for undo
    taskObj = _.clone user.get("#{type}s")[i]
    taskObj.completed = previous
    setUndo _.clone(user.get('stats')), taskObj
    scoring.score(model, taskObj, direction)

  user.on 'set', 'dailys.*.completed', (i, completed, previous, isLocal, passed) ->
    completedCallback(i, completed, previous, isLocal, passed, 'daily')
  user.on 'set', 'todos.*.completed', (i, completed, previous, isLocal, passed) ->
    completedCallback(i, completed, previous, isLocal, passed, 'todo')

  ###
    Undo
  ###
  appExports.undo = () ->
    undo = model.get '_undo'
    clearTimeout(undo.timeoutId) if undo?.timeoutId
    batch = character.BatchUpdate(model)
    batch.startTransaction()
    model.del '_undo'
    _.each undo.stats, (val, key) -> batch.set "stats.#{key}", val
    taskPath = "tasks.#{undo.task.id}"
    _.each undo.task, (val, key) ->
      return if key in ['id', 'type'] # strange bugs in this world: https://workflowy.com/shared/a53582ea-43d6-bcce-c719-e134f9bf71fd/
      if key is 'completed'
        user.pass({cron:true}).set("#{taskPath}.completed",val)
      else
        batch.set "#{taskPath}.#{key}", val
    batch.commit()

  appExports.tasksToggleAdvanced = (e, el) ->
    $(el).next('.advanced-option').toggleClass('visuallyhidden')

  appExports.tasksSaveAndClose = ->
    # When they update their notes, re-establish tooltip & popover
    $('[rel=tooltip]').tooltip()
    $('[rel=popover]').popover()

  appExports.tasksSetPriority = (e, el) ->
    dataId = $(el).parent('[data-id]').attr('data-id')
    model.at(e.target).set 'priority', $(el).attr('data-priority')