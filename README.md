lypse (Meteor + Knockout = apocaLYPSE)
========================================
Apocalypse is a library to facilitate rapid-application development in Meteor. 
It follows the philosophy that, given a powerful basis of syntactic sugar,
you can build the majority of a webapp purely from the HTML view.

It capitalizes on the wonderful basis of knockout.meteor and extends this
library to allow knockout view models that are both bindable AND persistent.

It then includes useful extensions that make it easier to write form-based UIs
and provide intelligent sorting and filtering.

We're working coffeescript, because it's awesome.

Basics - Setting up the Model
-----------------------------

Declare your meteor collections on the server and client side:

    @Notes = new Meteor.Collection('notes')

Now set up your model. Specify the fields and given them a description.
The description doesn't have any purpose for a primitive type, There are
plans to simplify this in the future.

    class Note extends LypseModel
       @collection: Notes
       @fields:
          author:     'string'
          text:       'string'
          date:       'date'
       init: =>
          @seen = ko.observable(false)
       click: =>
          @seen(true)

We specify the collection this model works from and the fields.
Again, the string values of the fields map can be anything.

Additionally, you can add an init function that gets called
when the object is created an specify additional client side
functions and fields. Only the fields in @fields are persisted to the db.

Now, grab the notes for your knockout viewmodel.

    class Viemodel
       constructor: ->
          @notes = ly.model(Note)

This will grab and wrap all Notes in the db. We will cover filters
and selectors later.

Now that's it! You are done with the coffeescript, we're ready to bind!


Basics - Setting up the View
-------------------------------

In your html:

    <body>
      <div data-bind="foreach: notes">
        <blockquote>
          <p><span data-bind="text: text"></span></p>
          <small><span data-bind="text: author"></span> on <span data-bind="text: date"></span></small>
        </blockquote>
      </div>
    </body>

And you're done, we can now add new notes and they'll display.


Basics - Adding elements and forms
-----------------------------------

