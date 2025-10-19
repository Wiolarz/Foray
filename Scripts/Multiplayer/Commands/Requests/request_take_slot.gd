class_name RequestTakeSlot

const COMMAND_NAME = "take_slot"

static func register(commands : Dictionary):
	commands[COMMAND_NAME] = \
			Command.create_on_server(RequestTakeSlot.process_command)

static func create_packet(slot_index : int):
	return {
		"name": COMMAND_NAME,
		"slot": slot_index,
	}

static func process_command(server : Server, peer : ENetPacketPeer, \
		params : Dictionary) -> int:
	var session : Server.Session = server.get_session_by_peer(peer)
	if session == null:
		return FAILED
	if not "slot" in params or not params["slot"] is int:
		return FAILED
	var slots = IM.game_setup_info.slots
	var index = params["slot"] as int
	if index < 0 or index >= slots.size():
		return FAILED
	var slot = IM.game_setup_info.slots[index]
	# if player uses name "1" it's still treated as a string
	if slot.occupier is int or server.settings.allow_slot_steal():
		slot.occupier = session.username
		server.broadcast_full_game_setup(IM.game_setup_info)
		IM.game_setup_info_changed.emit()
	return OK
