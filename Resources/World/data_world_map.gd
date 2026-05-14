class_name DataWorldMap
extends DataGenericMap

"""
Placeholder variables.

Complete world map data:
	1 Placement of every tile type
	2 Info about assignment of every city
"""
## player_idx : Race (can be null for any race)
@export var player_slots : Dictionary[int, DataRace] = {}

static func get_network_id(world_map : DataWorldMap) -> String:
	return world_map.resource_path.get_file() if world_map else ""


static func from_network_id(network_id : String) -> DataWorldMap:
	if network_id.is_empty():
		return null
	return load("%s/%s" % [ CFG.WORLD_MAPS_PATH, network_id ]) as DataWorldMap
