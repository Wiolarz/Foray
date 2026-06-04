class_name RequestArrow

const COMMAND_NAME = "arrow"

static func register(commands : Dictionary):
	commands[COMMAND_NAME] = \
			Command.create_on_server(RequestArrow.process_command)

static func create_packet(message : String):
	return {
		"name": COMMAND_NAME,
		"content": message,
	}

static func process_command(server : Server, peer : ENetPacketPeer, \
		params : Dictionary) -> int:
	var session : Server.Session = server.get_session_by_peer(peer)
	if session == null:
		return FAILED
	if not "content" in params or not params["content"] is String:
		return FAILED
	var message : String = params["content"]
	var author : String  = session.username

	server.broadcast_arrow_message(message, author)
	NET.draw_allies_arrow(message, author)
	return OK
