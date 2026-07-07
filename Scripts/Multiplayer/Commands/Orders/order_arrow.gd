class_name OrderArrow

const COMMAND_NAME = "server_arrow"

static func register(commands : Dictionary):
	commands[COMMAND_NAME] = \
			Command.create_on_client(OrderArrow.process_command)

static func create_packet(message : String, author : String):
	return {
		"name": COMMAND_NAME,
		"content": message,
		"author": author,
	}

static func process_command(client : Client, params : Dictionary) -> int:
	if client.username == "":
		return FAILED
	if not "content" in params or not params["content"] is String:
		return FAILED
	if not "author" in params or not params["author"] is String:
		return FAILED
	var message = params["content"]
	var author = params["author"]
	NET.draw_allies_arrow(message, author)
	return OK
