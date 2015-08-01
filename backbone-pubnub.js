(function() {
  (function(factory) {
    if (typeof define === "function" && define.amd) {
      return define(["underscore", "backbone", "exports"], factory);
    } else if (typeof exports === "object") {
      return factory(require("underscore"), require("backbone"), exports);
    } else {
      return factory(_, Backbone, {});
    }
  })(function(_, Backbone, PubNub) {
    var _sync;
    Backbone.PubNub = function(ref, name) {
      var _this = this;
      this.name = name;
      this.ref = ref;
      this.uuid = this.ref.uuid();
      this.channel = "backbone-" + this.name;
      this.records = [];
      return this.ref.subscribe({
        channel: this.channel,
        callback: function(message) {
          if (message.uuid !== _this.uuid) {
            switch (message.method) {
              case "create":
                return _this.create(message.model);
              case "update":
                return _this.update(message.model);
              case "delete":
                return _this.destroy(message.model);
            }
          }
        }
      });
    };
    _.extend(Backbone.PubNub.prototype, {
      publish: function(method, model, options) {
        var message;
        message = {
          method: method,
          model: model,
          options: options,
          uuid: this.uuid
        };
        return this.ref.publish({
          channel: this.channel,
          message: message
        });
      },
      read: function(model) {
        if (model.id == null) {
          return this.find(model.id);
        } else {
          return this.findAll();
        }
      },
      find: function(id) {
        return _.find(this.records, function(record) {
          return record.id === id;
        });
      },
      findAll: function() {
        return this.records;
      },
      create: function(model) {
        if (model.id == null) {
          model.id = this.ref.uuid();
          model.set(model.idAttribute, model.id);
        }
        this.records.push(model);
        this.publish("create", model);
        return model;
      },
      update: function(model) {
        var oldModel;
        oldModel = this.find(model.id);
        this.records[this.records.indexOf(oldModel)] = model;
        this.publish("update", model);
        return model;
      },
      destroy: function(model) {
        if (model.isNew()) {
          return false;
        }
        this.records = _.reject(this.records, function(record) {
          return record.id === model.id;
        });
        this.publish("delete", model);
        return model;
      }
    });
    Backbone.PubNub.sync = function(method, model, options) {
      var error, errorMessage, pubnub, resp, _ref;
      pubnub = (_ref = model.pubnub) != null ? _ref : model.collection.pubnub;
      console.log(method, model, options, pubnub);
      try {
        switch (method) {
          case "read":
            return resp = pubnub.read(model);
          case "create":
            return resp = pubnub.create(model);
          case "update":
            return resp = pubnub.update(model);
          case "delete":
            return resp = pubnub.destroy(model);
        }
      } catch (_error) {
        error = _error;
        errorMessage = error.message;
        return console.log("Could not sync: " + errorMessage);
      }
    };
    _sync = Backbone.sync;
    Backbone.sync = function(method, model, options) {
      var syncMethod;
      syncMethod = _sync;
      if (model.pubnub || (model.collection && model.collection.pubnub)) {
        syncMethod = Backbone.PubNub.sync;
      }
      return syncMethod.apply(this, [method, model, options]);
    };
    Backbone.PubNub.Collection = Backbone.Collection.extend({
      publish: function(method, model, options) {
        var message;
        message = {
          method: method,
          model: model,
          options: options,
          uuid: this.uuid
        };
        return this.pubnub.publish({
          channel: this.channel,
          message: message
        });
      },
      constructor: function(models, options) {
        var _this = this;
        Backbone.Collection.apply(this, arguments);
        if (options && options.pubnub) {
          this.pubnub = options.pubnub;
        }
        this.uuid = this.pubnub.uuid();
        this.channel = "backbone-collection-" + this.name;
        this.pubnub.subscribe({
          channel: this.channel,
          callback: function(message) {
            _this.off('change', _this._updateModel, _this);
            if (message.uuid !== _this.uuid) {
              switch (message.method) {
                case "create":
                  _this._onAdded(message.model, message.options);
                  break;
                case "update":
                  _this._onChanged(message.model, message.options);
                  break;
                case "delete":
                  _this._onRemoved(message.model, message.options);
              }
            }
            return _this.on('change', _this._updateModel, _this);
          }
        });
        return this.on('change', this._updateModel, this);
      },
      _updateModel: function(model) {
        return this.pubnub.publish("update", model);
      },
      history: function(options) {
        var defaults,
          _this = this;
        defaults = {
          count: 100,
          channel: this.channel,
          callback: function(results) {
            var messages;
            messages = _.chain(results).first().pluck('model').reject(_.isUndefined).value();
            _this.off('change', _this._updateModel, _this);
            _this.reset(messages);
            return _this.on('change', _this._updateModel, _this);
          }
        };
        return this.pubnub.history(_.extend(defaults, options));
      },
      _onAdded: function(model, options) {
        return Backbone.Collection.prototype.add.apply(this, [model, options]);
      },
      _onChanged: function(model, options) {
        var diff, record;
        if (!!model.id) {
          record = _.find(this.models, function(record) {
            return record.id === model.id;
          });
          if (record == null) {
            console.log("Could not find model with ID: " + model.id);
            return false;
          }
          diff = _.difference(_.keys(record.attributes), _.keys(model));
          _.each(diff, function(key) {
            return record.unset(key);
          });
          return record.set(model, options);
        }
      },
      _onRemoved: function(model, options) {
        return Backbone.Collection.prototype.remove.apply(this, [model, options]);
      },
      add: function(models, options) {
        var model, _i, _len;
        models = _.isArray(models) ? models.slice() : [models];
        for (_i = 0, _len = models.length; _i < _len; _i++) {
          model = models[_i];
          if (model.id == null) {
            model.id = this.pubnub.uuid();
          }
          this.publish("create", model, options);
        }
        return Backbone.Collection.prototype.add.apply(this, arguments);
      },
      remove: function(models, options) {
        var model, _i, _len;
        models = _.isArray(models) ? models.slice() : [models];
        for (_i = 0, _len = models.length; _i < _len; _i++) {
          model = models[_i];
          this.publish("delete", model, options);
        }
        return Backbone.Collection.prototype.remove.apply(this, arguments);
      }
    });
    Backbone.PubNub.Model = Backbone.Model.extend({
      publish: function(method, model, options) {
        var message;
        message = {
          method: method,
          model: model,
          options: options,
          uuid: this.uuid
        };
        return this.pubnub.publish({
          channel: this.channel,
          message: message
        });
      },
      constructor: function(model, options) {
        var _this = this;
        Backbone.Model.apply(this, arguments);
        if (options && options.pubnub && options.name) {
          this.pubnub = options.pubnub;
          this.name = options.name;
        }
        this.uuid = this.pubnub.uuid();
        this.channel = "backbone-model-" + this.name;
        this.on('change', this._onChange, this);
        return this.pubnub.subscribe({
          channel: this.channel,
          callback: function(message) {
            if (message.uuid !== _this.uuid) {
              switch (message.method) {
                case "update":
                  return _this._onChanged(message.model, message.options);
                case "delete":
                  return _this._onRemoved(message.options);
              }
            }
          }
        });
      },
      _onChange: function(model, options) {
        return this.publish("update", model, options);
      },
      _onChanged: function(model, options) {
        var diff,
          _this = this;
        this.off('change', this._onChange, this);
        diff = _.difference(_.keys(this.attributes), _.keys(model));
        _.each(diff, function(key) {
          return _this.unset(key);
        });
        this.set(model);
        return this.on('change', this._onChange, this);
      },
      _onRemoved: function(options) {
        return Backbone.Model.prototype.destroy.apply(this, arguments);
      },
      destroy: function(options) {
        this.publish("delete", null, options);
        return Backbone.Model.prototype.destroy.apply(this, arguments);
      }
    });
    return Backbone.PubNub;
  });

}).call(this);
