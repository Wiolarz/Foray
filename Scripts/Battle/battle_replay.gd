class_name BattleReplay
extends Resource

@export var timestamp : String
@export var battle_map: DataBattleMap
@export var units_at_start = [] # :Array[Array[DataUnit]]
@export var moves: Array[MoveInfo] = []

static func create(armies : Array[Army], c_battle_map: DataBattleMap):
	var result = BattleReplay.new()
	result.timestamp = Time.get_datetime_string_from_system()
	result.battle_map = c_battle_map
	for a in armies:
		result.units_at_start.append(a.get_units_list())
	return result

func record_move(m: MoveInfo) -> void:
	moves.append(m)

func get_filename() -> String:
	return timestamp.replace(":", "_") + ".tres"

func save():
	DirAccess.make_dir_recursive_absolute("user://replays/")
	ResourceSaver.save(self, "user://replays/" + get_filename())

