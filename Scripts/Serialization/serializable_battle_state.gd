extends Resource
class_name SerializableBattleState

@export var replay : BattleReplay

## used only when battle is in a world game
@export var world_armies : Array[Vector2i]
## used only when battle is in a world game
@export var combat_coord : Vector2i = Vector2i.MAX


func valid() -> bool:
	return replay != null


static func get_network_serialized(battle_state : SerializableBattleState) \
		-> PackedByteArray:
	var dict : Dictionary = {}
	var breplay = battle_state.replay
	if breplay:
		dict["moves"] = []
		var moves = dict["moves"]
		for move in breplay.moves:
			# HACK FIXME get rid of it and do it pretty
			var hacked_move = MakeMoveCommand.create_packet(move)
			moves.append(hacked_move)
	if battle_state.world_armies.size() > 0:
		dict["world_armies"] = battle_state.world_armies
	if battle_state.combat_coord < Vector2i.MAX:
		dict["combat_coord"] = battle_state.combat_coord

	return var_to_bytes(dict)


static func from_network_serialized(ser : PackedByteArray) \
		-> SerializableBattleState:
	var result = SerializableBattleState.new()
	var dict : Dictionary = bytes_to_var(ser)

	# replay
	if "moves" in dict and dict["moves"] is Array:
		var breplay = BattleReplay.new()
		breplay.timestamp = Time.get_datetime_string_from_system()
		# TODO maybe use create
		var moves = dict["moves"]
		for move in moves:
			# HACK again
			var hacked_move : MoveInfo = MakeMoveCommand.create_from(move)
			breplay.moves.append(hacked_move)

		result.replay = breplay

	# world connection
	if "world_armies" in dict and dict["world_armies"] is Array:
		for army_coord in dict["world_armies"]:
			result.world_armies.append(army_coord)

	if "combat_coord" in dict and dict["combat_coord"] is Vector2i:
		result.combat_coord = dict["combat_coord"]

	return result
