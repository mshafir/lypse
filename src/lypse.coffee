# General Modeling Utils
# =========
class Mapping
   map: (text, create_func) ->
      @[text] =
         create: create_func

@make_map = (key,value) ->
   m = {}
   m[key] = value
   return m

@vm = (vm) -> {'view_model':vm}

# Change Builders
# =========
# functions for handling change notifications and
# building modifiers for Mongo selectors

@mod_build = (obj,superfields...,field) ->
   if field?
      s = mod_build(obj.parent,superfields...)
      s + field + "." + _.indexOf(obj.parent[field](),obj) + "."
   else
      ""

@get_id = (obj) ->
   if not obj._id?
      get_id(obj.parent)
   else
      obj._id()

@get_sel_mod = (obj,superfields...,field,value) ->
   selector = {'_id':get_id(obj)}
   field_prefix = mod_build(obj,superfields...)
   modifier = make_map(field_prefix+field,value)
   [selector,modifier]

@do_update = (obj,collection,superfields...,field,value) ->
   [selector,modifier] = get_sel_mod(obj,superfields...,field,value)
   collection.update(selector, $set: modifier)

@do_insert = (obj,collection,superfields...,field,value) ->
   [selector,modifier] = get_sel_mod(obj,superfields...,field,value)
   collection.update(selector, $push: modifier)

@do_remove = (obj,collection,superfields...,field,value) ->
   [selector,modifier] = get_sel_mod(obj,superfields...,field,value)
   collection.update(selector, $pull: modifier)

# Link
# =======
# the link objects handles foreign keys in Lypse Models
class Link
   constructor: (@model, @selector) ->

@many = (collection, field, selector) ->
   new Link(collection, (self) ->
     if selector?
       m = selector
     else
       m = {}
     m[field] = self._id()
     return m)

# LypseModel
# =======
# this object forms the core of the lypse system. A
# class that derrives from LypseModel will be both bindable
# and persistent to the underlying mongo/meteor collection
class LypseModel
   #note: collection is collection or field
   constructor: (data,parent,path) ->
      #build the mapping
      mapping = new Mapping()
      for field,func of @constructor.fields
         do (field,func) =>
            if func instanceof Function
               #if it's in the data it must be a sub-document
               if field of data
                  obj = func()
                  mapping.map(field, (o) => new obj(o.data,@,path.concat(field)))
      #unwrap the data
      ko.mapping.fromJS(data, mapping, @)
      #build secondary links (foreign keys)
      for field,func of @constructor.fields
         if func instanceof Function
            obj = func()
            if obj instanceof Link
               @[field] = ko.meteor.model(obj.model.collection,obj.selector(@),{},obj.model,@)
      #set the parent element and path
      @parent = parent
      @path = path
      @data = data
      #set up the computed observables (NOTE: does not work)
      for k,v of @constructor.computed
         @[k] = ko.computed(() => v(@))
      #subscribe to change notifications
      #update the db when they happen
      #add convenience functions for inserts
      for key,value of data
         do (key,value) =>
            if key isnt '_id'
               if key not of @constructor.fields
                  console.log 'error: field "'+key+'" not declared'
               else if @constructor.fields[key] instanceof Function
                  @[key]['add'] = (newval) => do_insert(@,path...,key,newval)
               else
                  @[key].subscribe (newval) =>
                     do_update(@,path...,key,newval)
      #if it exists, do the subclass' initialization routine
      @init?()
   remove: () =>
      if @_id?
         @path[0].remove({_id: @_id()})
      else
         do_remove(@parent,@path...,@data)

# This is the core modelling function, performing a query
# and wrapping with the appropriate LypseModel instances
@new_model = (object,self) =>
   # we store filters and sorts as observables
   # that aren't modified on load, but afterwards with
   # a set of convenience predicates on the observable
   # model result
   filters = ko.observable({})
   sort = ko.observable([])
   limit = ko.observable(100)
   # the options are computed so they are re-applied on change
   options = ko.computed( =>
      result = {}
      s = ko.utils.unwrapObservable(sort)
      if s
        result.sort = s
      l = ko.utils.unwrapObservable(limit)
      if l
        result.limit = l
      return result)
   # calls into the core ko.meteor library to generate the wrapper
   model = ko.meteor.model(object.collection,filters,options,object,self)
   model.filters = filters
   model.sort = sort
   model.limit = limit
   # call into the sortfilter library to add convenience functions over the options
   return ly.sortfilter(model,object)

# convenience function to get an observable of a session variable
@session = (session) ->
   result = ko.observable(Session.get(session))
   Deps.autorun(() => result(Session.get(session)))
   result

# the higher-level lypse objects and functions to expose
@ly =
   make_map: make_map
   many: many
   Link: Link
   model: new_model
   session: session

root = exports ? this
root.ly = ly
root.LypseModel = LypseModel

