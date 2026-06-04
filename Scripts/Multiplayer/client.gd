class_name Client
extends Node


var username : String = ""
var peer : ENetPacketPeer = null
var send_queue : Array = []
var incoming_commands : Dictionary = {}
var server_settings_cache : ServerSettings

@onready var enet_network : ENetConnection = null


func _init():
	name = "Client"
	var order_paths = FileSystemHelpers.list_files_in_folder( \
			"res://Scripts/Multiplayer/Commands/Orders/", true)
	for path in order_paths:
		var script = load(path)
		print("registering order command '", script.COMMAND_NAME, \
				"' from file ", path.get_file())
		assert( not incoming_commands.has(script.COMMAND_NAME), \
				"dulicated server command: '%s'" % script.COMMAND_NAME)
		script.register(incoming_commands)

func _process(_delta):
	roll()

#region Connection

func connect_to_server(address : String, port : int) -> void:
	print("Requested connection to a server: %s:%d" % [ address, port ])
	if enet_network != null:
		print("Client was already connected -- disconnecting first")
		close()
	enet_network = ENetConnection.new()
	var error : Error = enet_network.create_host(1, 1)
	if error != OK:
		print("Could not create host")
	peer = enet_network.connect_to_host(address, port, 1, 0)
	if peer == null:
		print("Could not connect client")
		enet_network = null
		peer = null
		return
	print("No errors")


#endregion


#region Communication


func queue_login(desired_username : String) -> void:
	var packet : Dictionary = RequestLogin.create_packet(desired_username)
	queue_message_to_server(packet)


func queue_say(message : String):
	var packet : Dictionary = RequestSay.create_packet(message)
	queue_message_to_server(packet)


func queue_arrows(text_arrows : String):
	var packet : Dictionary = RequestArrow.create_packet(text_arrows)
	queue_message_to_server(packet)


func queue_cycle_color(slot_index : int, backwards : bool = false):
	var packet : Dictionary = \
		RequestColorCycle.create_packet(slot_index, backwards)
	queue_message_to_server(packet)


func queue_cycle_race(slot_index : int, backwards : bool = false):
	var packet : Dictionary = \
		RequestRaceCycle.create_packet(slot_index, backwards)
	queue_message_to_server(packet)


func queue_take_slot(slot_index : int):
	var packet : Dictionary = RequestTakeSlot.create_packet(slot_index)
	queue_message_to_server(packet)


func queue_leave_slot(slot_index : int):
	var packet : Dictionary = RequestLeaveSlot.create_packet(slot_index)
	queue_message_to_server(packet)


func queue_lobby_set_unit(slot_index:int, unit_index:int, unit_data:DataUnit):
	queue_message_to_server( \
			RequestLobbySetUnit.create_packet( \
				slot_index, unit_index, unit_data \
			))


func queue_lobby_set_team(slot_index : int, team_index : int):
	queue_message_to_server( \
			RequestLobbySetTeam.create_packet( \
				slot_index, team_index \
			))


func queue_lobby_set_timer(slot_index : int, reserve_sec : int, increment_sec : int):
	queue_message_to_server( \
			RequestLobbySetTimer.create_packet( \
				slot_index, reserve_sec, increment_sec \
			))


func queue_request_move(move : MoveInfo):
	queue_message_to_server(RequestBattleMove.create_packet(move))


func queue_request_world_move(move : WorldMoveInfo):
	queue_message_to_server(RequestWorldMove.create_packet(move))


func queue_request_game_state_sync():
	queue_message_to_server(RequestStateSync.create_packet())


func queue_request_start():
	queue_message_to_server(RequestStart.create_packet())


func logout_if_needed() -> void:
	if username == "":
		return
	var packet : Dictionary = RequestLogout.create_packet()
	username = ""
	send_message_to_server_immediately(packet)
	# TODO consider unrealiable packet send here


func desync() -> void:
	queue_request_game_state_sync()
	# TODO maybe some waiting


func close() -> void:
	print("Requested client disconnect")
	if enet_network == null:
		print("Client was not connected")
		return
	enet_network.flush()
	if peer:
		peer.peer_disconnect_later()
	enet_network.flush()
	enet_network.destroy()
	enet_network = null
	peer = null
	username = ""
	print("Client disconnected")


func queue_message_to_server(command_dictionary : Dictionary) -> void:
	if not command_dictionary is Dictionary:
		return
	var content : PackedByteArray = var_to_bytes(command_dictionary)
	send_queue.append(content)


func send_message_to_server_immediately(command_dictionary : Dictionary) -> void:
	if peer == null:
		return
	var content : PackedByteArray = var_to_bytes(command_dictionary)
	peer.send(0, content, ENetPacketPeer.FLAG_RELIABLE)
	enet_network.flush()


func roll() -> void:
	var broken : bool = false
	while true:
		if not enet_network:
			return
		var event : Array = enet_network.service()

		var type : ENetConnection.EventType = event[0]
		assert(type == ENetConnection.EventType.EVENT_NONE \
				or peer == event[1], "got event not from server")
		var channel : int = event[3]

		match type:
			ENetConnection.EventType.EVENT_ERROR:
				print("Error at server service -- server will be destroyed")
				broken = true
				break
			ENetConnection.EventType.EVENT_NONE:
				break
			ENetConnection.EventType.EVENT_CONNECT:
				print("Connected to server")
			ENetConnection.EventType.EVENT_DISCONNECT:
				print("Disconnected")
				peer = null
				enet_network = null
				return
			ENetConnection.EventType.EVENT_RECEIVE:
				var packet : PackedByteArray = peer.get_packet()
				if channel != 0:
					print("Server sent something on different channel than 0 -- ignoring")
				var decoded = MultiCommon.decode_packet(packet)
				if not decoded:
					print("Server sent something not being a command")
					break
				var command_name = decoded["name"]
				print("server sent us command %s" % [ command_name ])
				if not command_name in incoming_commands:
					print("server sent us unknown command %s" % [ command_name ])
					break
				var command = incoming_commands[command_name]
				if command.client_callback:
					var result = (command.client_callback).call(self, decoded)
					if result != 0:
						print("server sent us %s command, but we couldn't process it well" % [ command_name ])
					break
					print("command processed")
	if peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
		while send_queue.size() != 0:
			var content = send_queue[0]
			send_queue.remove_at(0)
			peer.send(0, content, ENetPacketPeer.FLAG_RELIABLE)
	if broken:
		close()

#endregion Communication


func is_slot_steal_allowed() -> bool:
	return server_settings_cache.allow_slot_steal()
