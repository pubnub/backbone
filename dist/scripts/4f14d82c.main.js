!function(){var a;Backbone.PubNub=function(a,b){var c=this;return this.name=b,this.ref=a,this.uuid=this.ref.uuid(),this.channel="backbone-"+this.name,this.records=[],this.ref.subscribe({channel:this.channel,callback:function(a){if(a=JSON.parse(a),a.uuid!==c.uuid)switch(a.method){case"create":return c.create(a.model);case"update":return c.update(a.model);case"delete":return c.destroy(a.model)}}})},_.extend(Backbone.PubNub.prototype,{publish:function(a,b,c){var d;return d={method:a,model:b,options:c,uuid:this.uuid},d=JSON.stringify(d),this.ref.publish({channel:this.channel,message:d})},read:function(a){return null==a.id?this.find(a.id):this.findAll()},find:function(a){return _.find(this.records,function(b){return b.id===a})},findAll:function(){return this.records},create:function(a){return null==a.id&&(a.id=this.ref.uuid(),a.set(a.idAttribute,a.id)),this.records.push(a),this.publish("create",a),a},update:function(a){var b;return b=this.find(a.id),this.records[this.records.indexOf(b)]=a,this.publish("update",a),a},destroy:function(a){return a.isNew()?!1:(this.records=_.reject(this.records,function(b){return b.id===a.id}),this.publish("delete",a),a)}}),Backbone.PubNub.sync=function(a,b){var c,d,e,f,g;e=null!=(g=b.pubnub)?g:b.collection.pubnub;try{switch(a){case"read":return f=e.read(b);case"create":return f=e.create(b);case"update":return f=e.update(b);case"delete":return f=e.destroy(b)}}catch(h){return c=h,d=c.message,console.log("ERROR",c)}},a=Backbone.sync,Backbone.sync=function(b,c,d){var e;return e=a,(c.pubnub||c.collection&&c.collection.pubnub)&&(e=Backbone.PubNub.sync),e.apply(this,[b,c,d])},Backbone.PubNub.Collection=Backbone.Collection.extend({publish:function(a,b,c){var d;return d={method:a,model:b,options:c,uuid:this.uuid},d=JSON.stringify(d),this.pubnub.publish({channel:this.channel,message:d})},constructor:function(a,b){var c,d=this;return Backbone.Collection.apply(this,arguments),b&&b.pubnub&&(this.pubnub=b.pubnub),this.uuid=this.pubnub.uuid(),this.channel="backbone-collection-"+this.name,this.pubnub.subscribe({channel:this.channel,callback:function(a){if(a=JSON.parse(a),a.uuid!==d.uuid)switch(a.method){case"create":return d._onAdded(a.model,a.options);case"update":return d._onChanged(a.model,a.options);case"delete":return d._onRemoved(a.model,a.options)}}}),c=function(a){return this.publish("update",a)},this.listenTo(this,"change",c,this)},_onAdded:function(a,b){return Backbone.Collection.prototype.add.apply(this,[a,b])},_onChanged:function(a,b){var c,d;if(a.id){if(d=_.find(this.models,function(b){return b.id===a.id}),null==d)throw new Error("Could not find model with ID: "+a.id);return c=_.difference(_.keys(d.attributes),_.keys(a)),_.each(c,function(a){return d.unset(a)}),d.set(a,b)}},_onRemoved:function(a,b){return Backbone.Collection.prototype.remove.apply(this,[a,b])},add:function(a,b){var c,d,e;for(a=_.isArray(a)?a.slice():[a],d=0,e=a.length;e>d;d++)c=a[d],null==c.id&&(c.id=this.pubnub.uuid(),c.set(c.idAttribute,c.id)),this.publish("create",c,b);return Backbone.Collection.prototype.add.apply(this,arguments)},remove:function(a,b){var c,d,e;for(a=_.isArray(a)?a.slice():[a],d=0,e=a.length;e>d;d++)c=a[d],this.publish("delete",c,b);return Backbone.Collection.prototype.remove.apply(this,arguments)}}),Backbone.PubNub.Model=Backbone.Model.extend({publish:function(a,b,c){var d;return d={method:a,model:b,options:c,uuid:this.uuid},d=JSON.stringify(d),this.pubnub.publish({channel:this.channel,message:d})},constructor:function(a,b){var c=this;return Backbone.Model.apply(this,arguments),b&&b.pubnub&&b.name&&(this.pubnub=b.pubnub,this.name=b.name),this.uuid=this.pubnub.uuid(),this.channel="backbone-model-"+this.name,this.on("change",this._onChange,this),this.pubnub.subscribe({channel:this.channel,callback:function(a){if(a=JSON.parse(a),a.uuid!==c.uuid)switch(a.method){case"update":return c._onChanged(a.model,a.options);case"delete":return c._onRemoved(a.options)}}})},_onChange:function(a,b){return this.publish("update",a,b)},_onChanged:function(a){var b,c=this;return this.off("change",this._onChange,this),b=_.difference(_.keys(this.attributes),_.keys(a)),_.each(b,function(a){return c.unset(a)}),this.set(a),this.on("change",this._onChange,this)},_onRemoved:function(){return Backbone.Model.prototype.destroy.apply(this,arguments)},destroy:function(a){return this.publish("delete",null,a),Backbone.Model.prototype.destroy.apply(this,arguments)}})}.call(this),function(){var a,b,c,d,e,f,g,h,i,j,k,l;l=PUBNUB.uuid(),k=PUBNUB.init({subscribe_key:"sub-c-4c7f1748-ced1-11e2-a5be-02ee2ddab7fe",publish_key:"pub-c-6dd9f234-e11e-4345-92c4-f723de52df70",uuid:l}),e=Backbone.Model.extend({defaults:function(){return{title:"empty todo...",order:h.nextOrder(),done:!1}},toggle:function(){return this.save({done:!this.get("done")})}}),f=Backbone.PubNub.Collection.extend({model:e,name:"TodoList",pubnub:k,constructor:function(){return Backbone.PubNub.Collection.apply(this,arguments),this.listenTo(this,"remove",function(a){return a.destroy()})},done:function(){return this.where({done:!0})},remaining:function(){return this.without.apply(this,this.done())},nextOrder:function(){return this.length?this.last().get("order")+1:1},comparator:"order"}),h=new f,g=Backbone.View.extend({tagName:"li",template:_.template($("#item-template").html()),events:{"click .toggle":"toggleDone","dblclick .view":"edit","click a.destroy":"clear","keypress .edit":"updateOnEnter","blur .edit":"close"},initialize:function(){var a=this;return this.listenTo(this.model,"change",this.render),this.listenTo(this.model,"destroy",function(){return a.remove()})},render:function(){return this.$el.html(this.template(this.model.toJSON())),this.$el.toggleClass("done",this.model.get("done")),this.input=this.$(".edit"),this},toggleDone:function(){return this.model.toggle()},edit:function(){return this.$el.addClass("editing"),this.input.focus()},close:function(){var a;return a=this.input.val(),a?(this.model.save({title:a}),this.$el.removeClass("editing")):this.clear()},updateOnEnter:function(a){return 13===a.keyCode?this.close():void 0},clear:function(){return this.model.destroy()}}),b=Backbone.View.extend({el:$("#todoapp"),statsTemplate:_.template($("#stats-template").html()),events:{"keypress #new-todo":"createOnEnter","click #clear-completed":"clearCompleted","click #toggle-all":"toggleAllCompleted"},initialize:function(){return this.input=this.$("#new-todo"),this.allCheckbox=this.$("#toggle-all")[0],this.listenTo(h,"add",this.addOne),this.listenTo(h,"reset",this.addAll),this.listenTo(h,"all",this.render),this.footer=this.$("footer"),this.main=$("#main")},render:function(){var a,b;return a=h.done().length,b=h.remaining().length,h.length?(this.main.show(),this.footer.show(),this.footer.html(this.statsTemplate({done:a,remaining:b}))):(this.main.hide(),this.footer.hide()),this.allCheckbox.checked=!b},addOne:function(a){var b;return b=new g({model:a}),this.$("#todo-list").append(b.render().el)},addAll:function(){return h.each(this.addOne,this)},createOnEnter:function(a){return 13===a.keyCode&&this.input.val()?(h.create({title:this.input.val()}),this.input.val("")):void 0},clearCompleted:function(){return _.invoke(h.done(),"destroy"),!1},toggleAllCompleted:function(){var a;return a=this.allCheckbox.checked,h.each(function(b){return b.save({done:a})})}}),a=new b,c=Backbone.PubNub.Model.extend({name:"MyModel",pubnub:k,defaults:function(){return{rand:Math.random(),title:"My Model"}}}),j=new c,d=Backbone.View.extend({el:$("#mymodel"),template:_.template($("#mymodel-template").html()),events:{"click #update":"onUpdateClick","click #delete":"onDeleteClick"},initialize:function(){return this.listenTo(j,"destroy",this.render),this.listenTo(j,"all",this.render),this.render()},onUpdateClick:function(){return j.set({rand:Math.random()})},onDeleteClick:function(){return j.destroy()},render:function(){return this.$el.html(this.template(j.toJSON()))}}),i=new d,k.subscribe({channel:l,callback:function(a){var b;return b=a,h.set(b)},connect:function(){return k.publish({channel:"getTodos",message:{uuid:l}})}})}.call(this);