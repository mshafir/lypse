# LypseSort
# =================
# Author: Michael Shafir
#
# This library extends LypseModels with useful sorting/filtering capabilities
#

# FilterSet
# ----------------
# Data structure storing labeled filters and capable of
# turning filters on/off and calculating a combined
# data struct (map or list) of the current active set
class FilterSet
  # Constructor
  # ----------------
  # builds a filter set, typeMap specifies whether the storage
  # data structure should be a map (for db filters) or not (for functional filters)
  constructor: (@typeMap = false) ->
    @map = {}
    @dependencies = {}
    @active = {}
    @values = {}
    @activeSet = if @typeMap then ko.observable({}) else ko.observable([])


  addEntry: (label,value) =>
    console.log 'adding filter '+label
    @map[label] = value
    @active[label] = ko.observable(false)
    @dependencies[label] = []

  # Add
  # -----------
  # specifies a new set of filters to the filter set
  # the input is of the format {label1: filterspec, label2: filterspec2}
  # where label1 and label2 will be registered as dependent, meaning
  # that by setting label1 to on, label2 will be turned off and vice versa
  add: (item) =>
    for k,v of item
      @addEntry(k,v)
      for k2 of item
        if k isnt k2
          @dependencies[k].push(k2)
    return @

  # Add Valued
  # --------------
  # creates a ko.observable of 'name' in the FilterSet.values map
  # when this observable is non-empty a filter will auto-activate
  # Example:
  #     model = ly.model(@Poems)
  #     model.filters.addValued('upvotes')
  #     # this observable was just created
  #     model.filters.values.upvotes(5)  # model will be only those poems with exactly 5 upvotes
  #     model.filters.addValued('upvotes','$gt')
  #     model.filters.values.upvotes(5)  # model will be those poems with greater than 5 upvotes
  #     model.filters.values.upvotes()   # model will be reset
  #
  addValued: (name, operator) =>
    valueobs = ko.observable('')
    @values[name] = valueobs
    if operator?
      valmap = ko.computed( =>
        result = {}
        resop = {}
        resop[operator] = @values[name]()
        result[name] = resop
        console.log 'rewriting to:'
        console.log result
        return result)
    else
      valmap = {}
      valmap[name] = valueobs
    @addEntry(name,valmap)
    valueobs.subscribe( (newval) =>
      if newval? and newval isnt ''
        @set(name)
      else
        @unset(name))

  checkHasFilter: (label) =>
    if label not of @map
      #TODO: throw
      console.log("Couldn't set label "+label+" because it wasn't specified.")

  # Set
  # ---------
  # sets the filter with the given label to be active,
  # this deactivates dependent filters
  # triggers recalculation of the active filter set
  set: (label) =>
    @checkHasFilter(label)
    @active[label](true)
    for deplabel in @dependencies[label]
      @active[deplabel](false)
    @recalculateActiveSet()
    return @

  # Unset
  # --------
  # sets the filter with the given label to be inactive
  # triggers recalculation of the active filter set
  unset: (label) =>
    @checkHasFilter(label)
    @active[label](false)
    @recalculateActiveSet()
    return @

  # Toggle
  # --------
  # toggles the filter with the given label on/off
  # triggers recalculation of the active filter set
  toggle: (label) =>
    if @active[label]()
      @unset(label)
    else
      @set(label)

  # Status
  # --------
  # returns an observable that equals
  # true if a filter with the given label exists
  # and is active
  status: (label) =>
    if label of @map
      @active[label]
    else
      console.log('The label '+label+' was not specified in the filter set.')

  # Recalculate Active Set
  # ------------------------
  # recomputes the data structure (map or list)
  # storing the currently active filters
  # and sets the observable representing this set
  recalculateActiveSet: () =>
    result = if @typeMap then {} else []
    for label,isOn of @active
      if isOn()
        val = ko.utils.unwrapObservable(@map[label])
        console.log label+":"
        console.log val
        if @typeMap
          #TODO: check map
          for k,v of val
            result[k] = ko.utils.unwrapObservable(v)
        else
          #TODO: check function
          result.push(val)
    @activeSet(result)

# sortfilter is the key wrapping function that add conveniences
# methods into the bindable model returned by ly.model
@sortfilter = (basemodel,object) ->
  model = ko.observable(basemodel())
  model.base = basemodel
  model.filters = basemodel.filters
  model.sort = basemodel.sort
  model.limit = basemodel.limit

  # ability to fetch more documents (? does rewrapping happen ?)
  model.fetch = (amount = 100) => model.limit(model.limit()+amount)

  # Sorts
  # =========
  # The idea behind the sorting architecture is to allow
  # simple, but flexible sorting convenience calls
  # For example:
  #     # sort (primary) by name ascending
  #     model.sortBy.asc.name()
  #     # secondary sort by position descending
  #     model.sortBy.desc.position()
  #
  #     # query for sorting by
  #     model.sortingBy.name()  # yields 1 (primary sort)
  #     model.sortingBy.desc.position()  # yields 2 (secondary sort)
  #     model.sortingBy.asc.position() # yields -1 (not sorting by)
  #
  #     # you can also chain sort commands
  #     model.sortBy.asc.name().desc.position()
  #
  # This convenience capability is so that sorts operations
  # can easily be bound from the html
  #
  # Sort Setup Code
  # ----------------
  model.sortingBy = {}
  model.sortingBy.asc = {}
  model.sortingBy.desc = {}
  model.sortBy = {}
  model.sortBy.asc = {}
  model.sortBy.desc = {}

  for field of object.fields
    do (field) ->
      # test for which fields you are sorting by
      model.sortingBy.asc[field] = ko.observable(-1)
      model.sortingBy.desc[field] = ko.observable(-1)
      model.sortingBy[field] = ko.observable(-1)
      # clear sorts
      model.newSort = () =>
        model.sort([])
        for field of object.fields
          model.sortingBy.asc[field](-1)
          model.sortingBy.desc[field](-1)
          model.sortingBy[field](-1)
        return model.sortBy
      # apply sorts on db fields
      model.sortBy.asc[field] = () =>
        model.sort(model.sort().concat([[field,'asc']]))
        model.sortingBy[field](model.sort().length)
        model.sortingBy.asc[field](model.sort().length)
        return model.sortBy
      model.sortBy.desc[field] = () =>
        model.sort(model.sort().concat([[field,'desc']]))
        model.sortingBy[field](model.sort().length)
        model.sortingBy.desc[field](model.sort().length)
        return model.sortBy

  # Filters
  # =========
  # there are two types of filters (db/server-side and functional/client-side)
  # we want to allow either of these types
  # TODO: respond when client-side filters are aggressive by fetching more entries
  # Additionally, we allow the ability to assign a label to a filter
  # This will allow the filter to be easily turned On/Off and
  # allows a bindable check for the status of the filter
  #
  # Again, the goal here is to make the operations convenient enough
  # to be callable directly from the html
  #
  # Also, sometimes, filters toggle with each other. An example
  # is a most recent this day/month/year filter set.

  model.filters.db = new FilterSet(true)
  model.filters.func = new FilterSet(false)

  model.filters.db.activeSet.subscribe( (newval) =>
    model.filters(newval))

  recalcSet = () =>
    result = []
    for item in basemodel()
      allpass = true
      for func in model.filters.func.activeSet()
        if func(item)
          allpass = false
          break
      if allpass
        result.push(item)
    model(result)

  model.filters.func.activeSet.subscribe( recalcSet )
  model.base.subscribe( recalcSet )

  return model

root = exports ? this
root.ly.sortfilter = sortfilter


