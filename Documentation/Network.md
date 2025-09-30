# Network -- technical description and functionality addition manual

## Introduction

First thing is that we do not use default Godot's network mode with RPC etc.
We use *ENet* library, which is available in Godot (it's also backend for default
mode).

Some parts of this document are detailed technical information, but don't
worry, if you don't understand them, you can just skip them because probably
you don't need them. The most important part is the manual explaining how to
add new features to network engine.

## Short architecture description

There are 2 types of commands (file `Scripts/Multiplayer/command.gd`)
transferred over network:

* Orders -- sent from server to clients. Typically they are very authoritative
  and client's refusal to obey them ends with *desync*. They can also bring
  some useful information like chat messages etc. Orders are implemented in
  directory `Scripts/Multiplayer/Commands/Orders/`.
* Requests -- sent from clients to server. They can be anything client wants
  to request from server, for example making a game move or sending something
  to chat. Server decides whether it fulfills these requests (for example,
  illegal game move will be rejected). Some of requests have their
  corresponding orders, for example, requesting a chat message makes server
  broadcast it to all clients. They are implemented in directory
  `Scripts/Multiplayer/Commands/Requests/`.

## Communication description

### Server setup

Everything begins with function
`server_listen(:String, :int, :String)` in network manager
(`Scripts/Multiplayer/NET_manager.gd`), which under the hoods calls
`make_server()` -- the function switching network manager to server mode, and
then `listen(:String, :int, :String)` in `Scripts/Multiplayer/server.gd`, which
uses *ENet* stuff.

The `server_listen` function needs information about listen address and port
(classic network L3/L4 stuff). It also takes username for player (*peer*) who
is the host (and therefore an admin).

### Connection to server

This is a bit more complicated procedure. We start it with function
`client_connect_and_login(:String, :int, :String)` in network manager.

#### Making a connection

First, client uses *Enet* library to connect to the server
(`connect_to_server(:String, :int)` in `Scripts/Multiplayer/client.gd`). This
sets up *Enet* stuff, for example a *peer* which represents a client
in connection and UDP connection under the hood.

#### Logging in

After making a connection in section above, we have only ENet connection, which
is not enough. We also need to log as some user/player. This is where function
`queue_login(:String)` is used. It queues a login request with some basic info
about the user (currently it's only a name).

Next chapters explain why it is queued, but here the important thing is that
this request is later sent.

Server after receiving such request does following things:

* Checks whether request is valid.
* Creates a player session (currently, association of peer and user name).
  * If user name is used by other client, that client is kicked.
  * If user name is used by the server, server refuses to log the client in
    and kicks this client.
* When everything is good, server sends to client information about the new
  session (`Scripts/Multiplayer/ClientCommands/set_session_command.gd`)
  and additional things (eg. current game state if it exists) with function
  `send_additional_callbacks_to_logging_client(:ENetPacketPeer)`.

When client receives a session from server, it sets its name and assumes being
logged in.

### Broadcasting something by the server

Server can send commands (orders) to clients. Every command is serialized as
Godot dictionary with field "name" being reserved for command name. The name
of command is also used by its file name (prefixed by `order_` and without
extension). For example, command "chat", which broadcasts a chat message, has
name `chat` and its file
is `Scripts/Multiplayer/Commands/Orders/order_chat.gd`. This file contains
a class implementing certain interface (described later).

TODO fix name convention (where `order_` should be added).

Typically, sending of an order is initiated by a "broadcast_something" function
in `Scripts/Multiplayer/server.gd`, which creates a "packet" via command's
class method named `create_packet`. The packed created this way is then
broadcast with method `broadcast` of `Server`.

Client, when receives an order, decodes it (as Godot dictionary) and check the
order name. If order with this name is found, then its method named
`process_command` is called with decoded payload as a parameter (indirectly,
see function `roll()` in `Scripts/Multiplayer/client.gd`). `process_command`
method is responsible for doing everything that order requires.

`process_command` is called indirectly, because commands during load, all
commands are collapsed to object of `Command`, which has functions
`client_callback` and `server_callback`. This will be reworked.

One of next sections explains how to add a new order to the game.

### Sending something from client to server STUB

Client can send commands (requests) to server. Requests are very similar to
orders. Differences:

* Their files' names are prefixed by `request_`.
* They are started in `Client` by methods named "queue_something".
  * It creates a packet exactly the same way as it is done for orders.
  * Calls `queue_message_to_server` with created packet.
    * This function adds the packet to queue.
    * This queue is sent to server every time `roll` is called, i.e. every
      frame.

One of next sections explains how to add a new request to the game.

TODO fix name convention (where `request_` should be added).

### Logging out from server

There is a "logout" request, which tells the server, that client wants
to log out. It does not disconnects the client from server, just deletes
the session. To send this request, client calls function `logout_if_needed`,
which sends it skipping the request queue. Sadly, currently it's never called
without disconnection (See `Client`'s method `client_logout_and_disconnect`).

### Request queue

Solution with adding some request to queue instead of immediately sending
them was done because of problems with flushing `ENet` buffer. First, all
requests were meant to be sent immediately, but sometimes commands weren't
sent at all, especially when client disconnected "after" sending. Solution
was to flush the buffer after every request, but this would cause game to
hang on every request when connection is slow.

## Adding a new request

Let's say that new request has name "example".

* Create file `Scripts/Multiplayer/Commands/Requests/request_example.gd`
  and add these elements (look at other request files for reference):
  * `class_name RequestExample`
  * `static func register(:Dictionary)`
    This function adds command to global command map.
  * `static func create_packet( ? )`
    Function which converts information about request (probably custom class or
    a few variables) to dictionary sent over network. It may take arbitrary
    parameters.
  * `static func process_command(:Server, :ENetPacketPeer, :Dictionary) -> int`
    Handling of the request on the server side.
* In file `Scripts/Multiplayer/client.gd`:
  * add function `queue_example( ? )`:

    ```
    func queue_example(args):
      queue_message_to_server(RequestExample.create_packet(args))
    ```

* Use just added `queue_example` everywhere you want the client to send them.

## Adding a new order

Let's say again that new request has name "example".

* Create file `Scripts/Multiplayer/Commands/Orders/order_example.gd`
  and add these elements (look at other request files for reference):
  * `class_name OrderExample`
  * `static func register(:Dictionary)`
    This function adds command to global command map.
  * `static func create_packet( ? )`
    Function which converts information about order (probably custom class or
    a few variables) to dictionary sent over network. It may take arbitrary
    parameters.
  * `static func process_command(:Client, :Dictionary) -> int`
    Handling of the order on the client side.
* In file `Scripts/Multiplayer/server.gd` this is a bit more complicated than it
  is for requests. You may need one of 2 types of sending order:
  * Broadcast -- this is the case where server sends something too all clients.
    This is simple, just create function `broadcast_example( ? )`:

    ```
    func broadcast_example(args):
      broadcast(OrderExample.create_packet(args))
    ```

  * Send to one client -- you need to create a function `send...something` which
    will take a `peer` to which it needs to be sent as param. This function
    will have to call functions like `OrderExample.create_packet(args)` and
    `send_to_peer(peer, packet)`.
* Same as for requests -- use added functions where you want to use them.

## Adding a new battle action

Battle action uses a command pair `request_battle_move`
and `order_make_battle_move`. They are both encoded the same way, despite
of being of other types.

Every command should have values at keys:

* `move_type` -- it's a name of the action type. It's a string. All used types
  are defined in file `Scripts/AI/move_info.gd`. To add a new type, first
  define its name in this file.
  TODO change name to `action_type`.
* `move_source` -- source coord of a move. It's obvious for a normal "move",
  but it has to be a `Vector2` and is mandatory for every action (even when it
  is not needed).
  TODO change name to `source_coord` and make it optional.
* `target_tile_coord` -- target coord of a move. Also `Vector2` and mandatory,
  like source.
  TODO change name to `target_coord` and make it optional.
* `deploy_unit` -- name of unit which is to be deployed. String. Mandatory.
  For actions which does not deploy anything, it should be just an empty
  string.

If an action needs other parameters, they can be defined freely at any unused
key.

Let's say that new action type has name "example". Next subsections describe,
how to implement a new action in all needed places. If action type is already
implemented in single player mode, some parts may be already done.

### MoveInfo

First, action type needs to be implemented in `Scripts/AI/move_info.gd`.

* Add a const string identifying the type

```gdscript
const TYPE_EXAMPLE = "example"
```

* Add all new parameters as new member variables where other parameters are
  defined.
* Add a static function named `make_example` returning `MoveInfo`
  and parameters of your choice. It should return `MoveInfo` object with
  `move_type` set to newly chosen name.
* Add a case with your new type to `to_network_serializable` function.
  TODO rework this function to use `match` on the type.
* Add a case with your new type to `from_network_serializable` function. It
  should use previously created `make_example` function.
* Add something in region "notification for undo". For some reasons, it is
  unknown, dark and dangerous place in the code, so you need to explore it
  yourself.
* Add a friendly description of your new action to function `_to_string`.

### BM

In file `Scripts/Battle/battle_manager.gd`, find function `_perform_move_info`,
which is used by `perform_network_move` and add a case with your new type to
a match statement on `move_info.move_type`.

## Adding a new world action

It's similar to battle action, but uses a pair `request_world_move`
and `order_make_world_move`. They are both encoded the same way, despite
of being other types.

The only mandatory key is `move_type`. It's a string. Types are defined
in file `Scripts/AI/world_move_info.gd`. Of course, if an action needs some
parameters, they can be defined freely at any unused key.

Let's say that new action type has name "example". Next subsections describe,
how to implement a new action in all needed places. Same as in case of battle
actions, if action type is already implemented in single player mode, some
parts may be already done.

### WorldMoveInfo

First, add action type to `Scripts/AI/world_move_info.gd`.

* Add a const string identifying the type

```gdscript
const TYPE_EXAMPLE = "example"
```

* Add all new parameters as new member variables where other parameters are
  defined.
* Add a static function named `make_example`. It should return `WorldMoveInfo`
  object with `move_type` set to newly chosen name.
* Add a case of new type (same as for other types) there:
  * File `Scripts/Multiplayer/Commands/Requests/request_world_move.gd`,
    function `create_from` (deserialization).
  * File `Scripts/Multiplayer/Commands/Orders/order_make_world_move.gd`,
    function `create_from` (deserialization).
  * File `Scripts/Multiplayer/Commands/Requests/request_world_move.gd`,
    function `process_command` (dictionary check before deserialization).
  * File `Scripts/Multiplayer/Commands/Orders/order_make_world_move.gd`,
    function `process_command` (dictionary check before desrialization).
  * File `Scripts/Multiplayer/Commands/Requests/request_world_move.gd`,
    function `create_packet` (serialization).
  * File `Scripts/Multiplayer/Commands/Orders/order_make_world_move.gd`,
    function `create_packet` (serialization).
  Of course this part needs a refactor -- it's a mess.

### WM and world state

* Add `do_example` function to `Scripts/World/world_state.gd`.
* Add `check_example` function to `Scripts/World/world_state.gd`
* In file `Scripts/World/world_state.gd` add new "case" to if statements in
  function `do_move`.

## Dictionary

* desync -- desynchronization -- means that states on the server side
  and client side differ. Further function is not possible. When client notices
  that it is desynchronized, it requests a full state from server
  (`Scripts/Multiplayer/ServerCommands/requested_state_sync.gd`).
  TODO make server send "bad action" message when client requests an illegal
  action.
  See:
  * `Scripts/Multiplayer/client.gd` -- `desync() -> void`
  * `Scripts/Multiplayer/NET_manager.gd` -- `desync() -> void`
