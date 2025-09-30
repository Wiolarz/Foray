class_name RequestBattleMove

const COMMAND_NAME = "battle_move"

static func register(commands : Dictionary) -> void:
	commands[COMMAND_NAME] = \
			Command.create_on_server(RequestBattleMove.process_command)

static func create_packet(move: MoveInfo) -> Dictionary:
	var dict = move.to_network_serializable()
	dict["name"] = COMMAND_NAME
	return dict


static func process_command(_server : Server, _peer : ENetPacketPeer, \
		params : Dictionary) -> int:
	if not "move_type" in params or not params["move_type"] is String:
		return FAILED
	if not "move_source" in params or not params["move_source"] is Vector2i:
		return FAILED
	if not "target_tile_coord" in params or not params["target_tile_coord"] is Vector2i:
		return FAILED
	if not "deployed_unit" in params or not params["deployed_unit"] is String:
		return FAILED
	var move_info = OrderMakeBattleMove.create_from(params)
	# TODO check move legality before performing on server
	BM.perform_network_move(move_info)
	return OK

static func create_from(params : Dictionary) -> MoveInfo:
	return MoveInfo.from_network_serializable(params)
