class_name Server
extends Node

 # Dictionary[String -> Command]
var incoming_commands : Dictionary = {}


var server_username : String = ""
@onready var sessions : Array = []
@onready var enet_network : ENetConnection = null
var server_local_address : String = ""
var server_external_address : String = "-needs fetch-"
var settings : ServerSettings = ServerSettings.new()

func _init():
	name = "Server"

	var request_paths = FileSystemHelpers.list_files_in_folder( \
			"res://Scripts/Multiplayer/Commands/Requests/", true)
	for path in request_paths:
		var script = load(path)
		print("registering request command '", script.COMMAND_NAME, \
				"' from file ", path.get_file())
		assert( not incoming_commands.has(script.COMMAND_NAME), \
				"dulicated server command: '%s'" % script.COMMAND_NAME)
		script.register(incoming_commands)


func _process(_delta):
	roll()


#region Connection

func listen(address : String, port : int, username : String):
	print("Requested server to listen at %s:%d" % [ address, port ])
	if enet_network != null:
		print("Server was listening -- stopping it first")
		close()
	server_local_address = ""
	enet_network = ENetConnection.new()
	var error = enet_network.create_host_bound(address, port, 32, 0, 0, 0)
	if error == OK:
		server_local_address = address
		server_username = username
		print("Server successfully started to listen on %s:%d" % [ \
			address, port ])
		return
	print("Could not start to listen: %d" % error)
	enet_network.destroy()
	enet_network = null


func get_session_by_username(username : String) -> Session:
	if username == server_username:
		return null
	for session in sessions:
		if session.username == username:
			return session
	return null


func get_session_by_peer(peer : ENetPacketPeer) -> Session:
	for session in sessions:
		if session.peer == peer:
			return session
	return null


func create_or_get_session(username : String) -> Session:
	if username == server_username:
		return null
	var session : Session = get_session_by_username(username)
	if session != null:
		return session
	session = Session.new()
	sessions.append(session)
	session.username = username
	return session


func connect_peer_to_session(peer : ENetPacketPeer, session : Session):
	var previous_peer : ENetPacketPeer = session.peer
	session.peer = peer
	return previous_peer


func detach_session(session : Session):
	session.peer = null


func drop_session(session : Session):
	sessions.erase(session)


func kick_peer(peer : ENetPacketPeer, reason : String) -> void:
	var session = get_session_by_peer(peer)
	if session:
		sessions.erase(session)
	var message = OrderKicked.create_packet(reason)
	send_to_peer(peer, message)
	peer.peer_disconnect_later()


func kick_all() -> void:
	var peers : Array[ENetPacketPeer] = []
	for session in sessions:
		if session.peer != null:
			peers.append(session.peer)
	for peer in peers:
		kick_peer(peer, "kicked all peers")


func close():
	print("Stopping server")
	if enet_network == null:
		print("Server was not listening")
		return
	for session : Session in sessions:
		detach_session(session)
	enet_network.destroy()
	enet_network = null
	sessions.clear()
	server_username = ""
	print("Server stopped")

#endregion Connection


#region Communication

func send_to_peer(peer : ENetPacketPeer, command_dictionary : Dictionary):
	if not command_dictionary is Dictionary:
		return
	print("server - send to peer ", command_dictionary["name"])
	var content : PackedByteArray = var_to_bytes(command_dictionary)
	peer.send(0, content, ENetPacketPeer.FLAG_RELIABLE)


func broadcast(command_dictionary : Dictionary):
	print("server - broadcast ", command_dictionary["name"])
	if not command_dictionary is Dictionary or enet_network == null:
		return
	var content : PackedByteArray = var_to_bytes(command_dictionary)
	enet_network.broadcast(0, content, ENetPacketPeer.FLAG_RELIABLE)


func broadcast_chat_message(message : String, author : String):
	var packet : Dictionary = OrderChat.create_packet(message, author)
	broadcast(packet)


func broadcast_say(message : String):
	return broadcast_chat_message(message, server_username)


func broadcast_full_game_setup(game_setup : GameSetupInfo):
	if game_setup == null:
		game_setup = IM.game_setup_info
	var packet : Dictionary = \
		OrderFillGameSetup.create_packet(game_setup, server_username)
	# print("sending \n", packet)
	broadcast(packet)


func broadcast_start_game():
	broadcast(OrderStartGame.create_packet())


func broadcast_move(move : MoveInfo):
	broadcast(OrderMakeBattleMove.create_packet(move))


func broadcast_world_move(move : WorldMoveInfo):
	broadcast(OrderMakeWorldMove.create_packet(move))


func broadcast_server_settings():
	broadcast(OrderShareServerSettings.create_packet(settings.content))


func send_additional_callbacks_to_logging_client(peer : ENetPacketPeer):
	# share settings
	var settings_packet = OrderShareServerSettings.create_packet(settings.content)
	send_to_peer(peer, settings_packet)

	var game_in_progress : bool = \
		BM.battle_is_active() or WM.world_game_is_active()
	if game_in_progress:
		send_full_state_sync(peer)
	else:
		# sync lobby
		var game_setup = IM.game_setup_info
		var packet : Dictionary = \
			OrderFillGameSetup.create_packet(game_setup, server_username)
		send_to_peer(peer, packet)


func send_full_state_sync(peer : ENetPacketPeer):
	var game_setup = IM.game_setup_info
	var world_state = IM.get_serializable_world_state()
	var battle_state = IM.get_serializable_battle_state()
	var packet : Dictionary = \
		OrderSetFullState.create_packet(game_setup, world_state, battle_state,
			server_username)
	send_to_peer(peer, packet)


func set_setting(setting_name : String, value) -> void:
	settings.content[setting_name] = value
	broadcast_server_settings()


func roll() -> void:
	var broken : bool = false
	if not enet_network:
		return
	while true:
		var event : Array = enet_network.service()

		var type : ENetConnection.EventType = event[0]
		var peer : ENetPacketPeer = event[1]
		#var data = event[2]
		var channel : int = event[3]

		match type:
			ENetConnection.EventType.EVENT_ERROR:
				print("Error at server service -- server will be destroyed")
				broken = true
				break
			ENetConnection.EventType.EVENT_NONE:
				break
			ENetConnection.EventType.EVENT_CONNECT:
				print("New connection arrived %d" % peer.get_instance_id())
			ENetConnection.EventType.EVENT_DISCONNECT:
				var id : int = peer.get_instance_id()
				print("Connection %x disconnected" % id)
				var session = get_session_by_peer(peer)
				if session:
					detach_session(session)
			ENetConnection.EventType.EVENT_RECEIVE:
				var packet : PackedByteArray = peer.get_packet()
				if channel != 0:
					push_error(("Peer %x sent something on different channel " + \
						"than 0 -- ignoring") % peer.get_instance_id())
					break
				var decoded = MultiCommon.decode_packet(packet)
				if not decoded:
					push_error("Peer %x sent something not being a command" % \
						peer.get_instance_id())
					break
				var command_name = decoded["name"]
				print("peer %x sent us command %s" % [ peer.get_instance_id(), \
					command_name ])
				if not command_name in incoming_commands:
					print("peer %x sent us unknown command %s" % [ \
						peer.get_instance_id(), command_name ])
					break
				var command = incoming_commands[command_name]
				if command.server_callback:
					var result = (command.server_callback).call(self, peer, \
						decoded)
					if result != 0:
						var msg = ("Peer %x sent us %s command, but we " + \
							"couldn't process it well") % [ \
							peer.get_instance_id(), command_name ]
						print(msg)
					print("command processed")
				if command.game_callback:
					pass
	if broken:
		close()

#endregion Communication

## info on an accepted network connection to the client
class Session:
	var username : String = ""
	var peer : ENetPacketPeer = null
