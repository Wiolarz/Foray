class_name WorldHex
extends RefCounted

const PATH_TODO_MOVE_TO_CONFIG = "res://Scripts/World/Places/"

## place == null <=> hex is a sentinel
var place : Place = null

var army : Army = null

var data_tile : DataTile = null


func init_place(type_name : String, coord : Vector2i, \
		ser : Dictionary[String, Variant]) -> void:
	assert(not ser or ser["type"] == type_name)
	var loading_from_ser = ser.size() > 0
	if type_name == "SENTINEL":
		place = null
	elif type_name == "WALL":
		place = Place.create_basic(coord, false, type_name)
	elif type_name == "EMPTY":
		place = Place.create_basic(coord, true, type_name)
	else:
		# not hardcoded place, so we seek for a script or deserialize place
		# state
		if loading_from_ser:
			place = Place.from_network_serializable(ser, coord)
		else:
			_fill_place_with_script(type_name, coord)


func _fill_place_with_script(type_name : String, coord : Vector2i) -> void:
	var type_array : PackedStringArray = type_name.split(' ', false)
	if type_array.size() < 1:
		push_error("empty world tile type -- leaving sentinel here")
		return
	var script_path = "%s/%s.gd" % [ PATH_TODO_MOVE_TO_CONFIG, type_array[0] ]
	var script = load(script_path) as Script
	assert(script) # TODO throw some error on map load
	var args = type_array.slice(1)
	place = script.create_place(coord, args)
	# var army_preset : PresetArmy = place.get_army_at_start()
	# if army_preset:
	# 	army = Army.create_from_preset(army_preset)


func get_image() -> Resource:
	if place:
		var override = place.get_image_override()
		if override:
			return override
	if data_tile.texture_path != "":
		return load(data_tile.texture_path)
	return load(CFG.SENTINEL_TILE_PATH)
