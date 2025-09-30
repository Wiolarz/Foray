class_name Place
extends RefCounted # RefCounted is default

signal controller_changed()

# TODO make this not duplicated
const PATH_TODO_MOVE_TO_CONFIG = "res://Scripts/World/Places/"


#TODO decide on whatever to use player reference or simply a reference to the controller faction
## Controller Faction
var faction : Faction
var controller_index : int:  # network simplification
	get:
		# TODO make it so that neutral army creation and other places use unique functions and check if faction, instead of using -1 controller index
		#assert(faction, "Attempt to get controlled index of a place without a controller")
		if faction:
			return faction.controller_index
		return -1


var coord : Vector2i
var movable : bool = false

## used only in basic places which are not derived classes
var basic_type : String


static func create_basic(coord_ : Vector2i, movable_ : bool, basic_type_ : String) \
		-> Place:
	var place := Place.new()
	place.coord = coord_
	place.movable = movable_
	place.basic_type = basic_type_
	return place


#region Overridable functions
## overriding is optional as those function should do nothing in empty places

static func create_place(coord_ : Vector2i, _args : PackedStringArray) -> Place:
	# TODO add grid to args -- it would ge great also to add hex *atomically*
	# in this funciton
	var place := Place.new()
	place.coord = coord_
	return place


## Get starting Neutral Army defenders
func get_army_at_start() -> PresetArmy:
	return null


## Hero enters tile with an army
func interact(_army : Army) -> void:
	pass


## Occurs after every player ended their move
func on_end_of_round() -> void:
	pass


## STUB
func get_map_description() -> String:
	return ""


## Faction is used to mark which player captures that tile [br]
## used in places like outpost (which acts like a mine)
func capture(_faction : Faction) -> void:
	return


static func get_network_serializable(place : Place) -> Dictionary:
	if not place:
		return {}
	var dict : Dictionary = {}
	place.to_specific_serializable(dict)
	dict["type"] = place.get_type()
	dict["player"] = place.controller_index
	return dict


static func from_network_serializable(dict : Dictionary, coord_ : Vector2i) -> Place:
	var type = dict["type"]
	var script_path = "%s/%s.gd" % [ PATH_TODO_MOVE_TO_CONFIG, type ]
	var script = load(script_path) as Script
	assert(script)
	var place : Place = script.create_place(coord_, PackedStringArray())
	var player_index = dict["player"]
	place.controller_index = player_index
	place.paste_specific_serializable_state(dict)
	return place


func get_image_override() -> Resource:
	return null


func is_basic() -> bool:
	return get_script() == Place


## should be overridden by each place
## This function has to copy such information of state that it would be
## possible to add it to the state after "create_place" call
func to_specific_serializable(_dict : Dictionary) -> void:
	pass # does nothing for empty places


## shoould be overridden by each place
## This function has to recover every information that is not recovered by
## "create_place" of the type with defaults and changing player which is done
## earlier
func paste_specific_serializable_state(_dict : Dictionary) -> void:
	pass # does nothing for empty places

#endregion Overridable functions


func get_type() -> String:
	if not is_basic():
		return get_script().resource_path.get_file().get_basename()
	else:
		return basic_type
