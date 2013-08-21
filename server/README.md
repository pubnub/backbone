Todos Server
----------------
This is the source code for the server that saves all the todo models in history. It allows the example to pull the current todos in the client. Since all the sync commands are done through PubNub we can hook into those commands using the server so the client does not have to make ajax requests to the server.