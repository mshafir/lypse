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

    class ViewModel
       constructor: ->
          @notes = ly.model(Note)

    @model = new ViewModel()
    Meteor.startup(() -> ko.applyBindings model)

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

And you're done with the display, now on to the adding...


Basics - Adding elements and forms
-----------------------------------

Now, we want to add elements. Well that's easy too!
Lypse has a LypseForm base for creating bindable objects that can be persisted back to the database.

    class NoteForm extends LypseForm
        @source: Note
        defaults:
           author: -> 'anonymous'
           text: -> ''
           date: -> new Date()

We created an objected that extends LypseForm and whose @source points to the LypseModel we made earlier.
We can specify defaults for the Note fields with the defaults map.

Now we want to add this form as a new bindable element on our viewmodel:

    class ViewModel
        constructor: ->
            @notes = ly.model(Note)
            @noteForm = new NoteForm()

Now we have an awesome way to add new notes. Add the following into the body of our html:

    <div data-bind="with: noteForm">
        <h3>New Note:</h3>
        <div>Author: <input type="text" data-bind="value: author, valueUpdate: 'afterkeydown'"></div>
        <div><textarea data-bind="value: text, valueUpdate: 'afterkeydown'"></textarea></div>
        <button data-bind="click: add">Add Note</button>
    </div>

And that's it! The valueUpdates let our observables get the update right away. Notice we don't even need to use
an html form. The LypseForm class provides us with a convenient "add" call that will go ahead and add the note
to the database.

That's it! You have a fully fledged app that can add notes, open it in two browser tabs and see the persistence
and meteor updating in action. All of this is in about 30 lines of coffeescript and 10 lines of html!
