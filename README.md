PubNub Backbone
========

This is a framework for [Backbone](http://backbonejs.org) integration with [PubNub](http://pubnub.com). It works by syncronizing all create, update, and delete action between your Backbone collections. This gives real-time updating between Backbone collections and models on different clients.

PubNub is a real-time network that provides the core tools to build real-time applications and scale them globally. Backbone gives structure to web applications with bindings and events for web application data. Combining the two gives a rich application experience for multi-user applications such as collaboritive editing, chat rooms, and even multiplayer games.

Check out the demo here: [http://pubnub.github.io/backbone/](http://pubnub.github.io/backbone/)

# Installation

You can install the package using bower and `bower install pubnub-backbone` or by cloning this repository. Install the PubNub library along with this one in your html file like so, replacing the *'s with the PubNub version you want to use:

```html
<script src="http://cdn.pubnub.com/pubnub.min.js"></script>
<script src="/path/to/backbone-pubnub.min.js"></script>
```

# Getting Started

The framework works by syncronizing all create, update, and delete events between collections on all clients. This can be done manually through a plugin that hooks into the Backbone.sync method. This will give you a local collection that can be sync'ed with a remote collection that is kept up to date with PubNub. The other option is to use the custom classes provided to create a collection or model that is always in sync.

# Initialize PubNub

Once both libraries are installed and ready to go the first step is to create a shared instance of the PubNub library. This will allow your real-time collections and models to communicate across the PubNub network.

```javascript
var pubnub = PUBNUB.init({
  publish_key: 'demo',
  subscribe_key: 'demo'
});
```

# Backbone.PubNub.Collection

This collection takes the pubnub instance and a name and then publishes all create, update, and delete methods across clients using PubNub. The `name` property is used to generate a unique channel name so collections do not collide with each other. As a warning, with the same name will update each other regardless of what class they come from.

```javascript
var MyCollection = Backbone.PubNub.Collection.extend({
  name: 'MyCollection', // Used to namespace the updates to this collection
  pubnub: pubnub        // A global instance of PubNub
});

var myCollection = new MyCollection();
```

# Backbone.sync

The Backbone.sync method allows you to have a collection with a remote store, much like the LocalStorage module from the original Backbone Todos demo. This allows you to take updates from other clients when you want them and not automatically.

```javascript
var MyCollection = Backbone.Collection.extenc({
  name: 'MyCollection', // Used to namespace the updates to this collection
  pubnub: pubnub        // A global instance of PubNub
});

var myCollection = new MyCollection();
```

# Backbone.PubNub.Model

This will create a model that is updated in real-time across all instances. This works very similarly to the collection in that it publishes all changes across the PubNub network.

```javascript
var MyModel = Backbone.PubNub.Model.extend({
  name: 'MyModel',
  pubnub: pubnub
});

var myModel = new MyModel();
```

# License

The MIT License (MIT)

Copyright (c) 2013 PubNub

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
