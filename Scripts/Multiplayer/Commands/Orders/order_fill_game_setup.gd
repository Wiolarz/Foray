class_name OrderFillGameSetup

const COMMAND_NAME = "fill_game_setup"

static func register(commands : Dictionary):
	commands[COMMAND_NAME] = \
			Command.create_on_client(OrderFillGameSetup.process_command)

static func create_packet(game_setup : GameSetupInfo, server_username : String):
	return {
		"name": COMMAND_NAME,
		"setup" : game_setup.to_dictionary(server_username)
	}

static func process_command(_client : Client, params : Dictionary) -> int:
	print("Client - fill_game_setup: \n %s" % params)
	if not "setup" in params or not params["setup"] is Dictionary:
		return FAILED
	var setup = GameSetupInfo.from_dictionary(params["setup"], \
		NET.get_current_username())
	IM.game_setup_info = setup
	IM.game_setup_info_changed.emit()
	return OK
