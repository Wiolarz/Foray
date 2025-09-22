class_name Slot
extends Resource

## occupier identifies who uses this slot [br]
## its an `int` or a `String` [br]
## `int` -> AI level eg. 1 [br]
## `String == ""` -> we (local player) [br]
## `String != ""` -> remote player with specified network name [br]
var occupier = ""

## used for some simpleness at player in world
var index : int = -1

var team : int = 0

var timer_reserve_sec : int = CFG.CHESS_CLOCK_BATTLE_TIME_PER_PLAYER_MS
var timer_increment_sec : int = CFG.CHESS_CLOCK_BATTLE_TURN_INCREMENT_MS

## index of color see `CFG.TEAM_COLORS`
var color_idx : int = 0
var battle_bot_path : String


## for battle only mode
var units_list : Array[DataUnit] = [null,null,null,null,null] #TODO refactor to change variable to private as we have a clean getter for it

## Editable by the level up screen data_hero
var slot_hero : Hero = null

# for World mode only
var race : DataRace = null


"""
Human joins server, in terms of game he doesnt exist, he only receives info about game progression as visuals

When Human creates Bot or joins a specific UI Slot -> New Player is created
# Every slot has automatically assigned during lobby start either player or computer based on settings,
 so above scenario refers to changing that setting for specific slot

"""


#region Default setup stuff

"""
who gets to controll this player

Timer options:
	Starting time
	Increment per player turn

player color

player team


"""

func _init():
	if CFG.player_options.use_default_AI_players:
		occupier = 0

## asks about setting set in lobby
func is_bot() -> bool:
	return occupier is int


#endregion Default setup stuff


#region Battle setup

"""
controlled units
controlled hero + hero options

"""

## for "Custom battles" unit list creation
## ignores empty values in units_list
func get_units_list() -> Array[DataUnit]:
	var non_empty : Array[DataUnit] = []
	for unit in units_list:
		if not unit:
			continue
		non_empty.append(unit)
	return non_empty


## for replays
func set_units(new_units : Array[DataUnit]) -> void:
	for idx in range(units_list.size()):
		if idx >= new_units.size():
			units_list[idx] = null
			continue
		units_list[idx] = new_units[idx]


func set_units_length(value : int) -> void:
	units_list.resize(value)

#endregion Battle setup


#region World Setup

"""
TODO
"""

#endregion World Setup
