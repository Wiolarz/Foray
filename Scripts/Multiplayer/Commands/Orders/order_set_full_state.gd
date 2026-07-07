class_name OrderSetFullState
#STUB CLASS

const COMMAND_NAME = "set_full_state"

static func register(commands : Dictionary):
	commands[COMMAND_NAME] = \
			Command.create_on_client(OrderSetFullState.process_command)

static func create_packet(game_setup : GameSetupInfo, \
		world_state : SerializableWorldState, \
		battle_state : SerializableBattleState, \
		server_login : String):
	return {
		"name": COMMAND_NAME,
		"setup": game_setup.to_dictionary(server_login),
		"world": SerializableWorldState.get_network_serialized(world_state),
		"battle": SerializableBattleState.get_network_serialized(battle_state),
	}

static func process_command(_client : Client, params : Dictionary) -> int:
	if not "setup" in params or not params["setup"] is Dictionary:
		return FAILED
	if not "world" in params or not params["world"] is PackedByteArray:
		return FAILED
	if not "battle" in params or not params["battle"] is PackedByteArray:
		return FAILED
	var setup = GameSetupInfo.from_dictionary(params["setup"], \
		NET.get_current_username())
	var world_state : SerializableWorldState = \
		SerializableWorldState.from_network_serialized(params["world"])
	var battle_state : SerializableBattleState = \
		SerializableBattleState.from_network_serialized(params["battle"])
	if not world_state.valid():
		world_state = null
	if not battle_state.valid():
		battle_state = null
	IM.game_setup_info = setup
	IM.start_game(world_state, battle_state)  # launched when joining an already started game
	return OK
