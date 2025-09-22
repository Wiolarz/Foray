class_name DataBattleMap

extends DataGenericMap

## KEY: PlayerID VALUE: number of deployment tiles
@export var player_slots : Dictionary

static func get_network_id(battle_map : DataBattleMap) -> String:
	return battle_map.resource_path.get_file() if battle_map else ""


static func from_network_id(network_id : String) -> DataBattleMap:
	if network_id.is_empty():
		return null
	return load("%s/%s" % [ CFG.BATTLE_MAPS_PATH, network_id ]) as DataBattleMap
