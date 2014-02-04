###################################################################################
#
#  LypseForm
#        Michael Shafir
#
#    This library is intented to make the process of form creation simpler
#  through usage of lypse models.
#
###################################################################################

# An adder is an object that facilitates the population and creation of
# a new instance of a LypseModel objct.
#
# A LypseForm is a further abstracted bindable object that supports object creation.
#
# Example:
#    
# class Person extends LypseModel
#   @collection: People
#   @fields:
#      name: ''
#      email: ''
#
#
## Create a new person object and add it to the database     
# p = @adder(Person) 
# p.name('Michael Shafir')
# p.email('Michael.Shafir@gmail.com')
# p.add()  
#
## LypseForm for doing the same thing
# class PersonForm extends LypseForm
#   @source: Person
#    defaults:
#      name: () -> 'anonymoues'
#
# p = new PersonForm()
# p.name('Michael Shafir')
# p.email('Michael.Shafir@gmail.com')
# p.add()  
#
#
## the benefit to the form is that it supports defaults cleaner development
## there are plans to implement form validation as well

@unwrap_adder = (addr) ->
   result = {}
   for k,v of addr
      if k is '_id'
         continue
      #for observable arrays unwrap all the items recursively
      if ko.isObservable(v) and v() instanceof Array
         lst = []
         for item in v()
            lst.push unwrap_adder(item)
         result[k] = lst
      #for regular observables just unwrap the value
      else if ko.isObservable(v)
         result[k] = v()
   return result

@adder = (model,target) =>
   newobj = target ? {}
   newobj._id = ko.observable()
   for k,v of model.fields
      do (k,v) =>
         #this is the best way I can think of to know if something is a sub-model
         #we make sub-models into observableArrays with an .add on the array
         #and a .remove on each item. Also we subscribe to bulk changes to allow
         #for more fluid methods on data entry
         if v instanceof Function and typeof(v()) isnt 'object'
            result = ko.observableArray()
            result['add'] = () ->
               ret = adder(v())
               ret['remove'] = () ->
                  result.remove(ret)
                  result.onItemRemoved?(ret)
               result.push(ret)
               for sk,sv of ret
                  sv.subscribe?(() ->
                     result.onItemChanged?(ret)
                     newobj.onItemChanged?(ret))
               result.onItemAdded?(ret)
               return ret
            newobj[k] = result
         #things that aren't functions should just be single fields (SUBJECT TO CHANGE)
         else if v not instanceof Function
            newobj[k] = ko.observable('')
            newobj[k].subscribe () -> newobj.onItemChanged?(newobj)
   #if we're wrapping a top-level doc (has a collection)
   #then put a .add function that will throw it into the collection
   #and call the onAdding and onAdd events to handle prep and cleanup
   if model.collection?
      newobj['add'] = () =>
         newobj.onAdding?(newobj)
         model.collection.insert(unwrap_adder(newobj),
              (error, id) ->
                  if error
                    console.log(error)
                  newobj._id(id))
         newobj.onAdd?(newobj)
         newobj
   return newobj

@empty_observable_item = (it) ->
   for f in it
      if f.name is 'observable'
         if f()? and f() isnt ''
            return false
   return true

class LypseForm
   constructor: () ->
      #make this an Adder for the source object
      adder(@constructor.source,@)
      #set defaults
      if @defaults
         for field,func of @defaults
            console.log 'setting default field '+field+' to '+func(@)
            @[field](func(@))
      #call the init
      @init?()
   onAdd: (obj) ->
      #usually we want to clear all fields
      for f of @
         if ko.isObservable(f) and f() instanceof Array
            f.removeAll()
         else if ko.isObservable(f)
            f(null)
   onAdding: (obj) ->
      #remove empty subfields 
      for key,f of @
         if ko.isObservable(f) and f() instanceof Array
            for item in f()
               if empty_observable_item(item)
                  item.remove()
   load: ->
      #set the defaults again (in case they changed)
      if @defaults
         for field,func of @defaults
            @[field](func(@))
      @init?()

root = exports ? this
root.ly.adder = adder
root.LypseForm = LypseForm

