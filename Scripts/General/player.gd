class_name Player
extends Node

"""
Simple class that gameplay wise is used only to verify who gets to controll this specific index units
It seperate from battle and world gameplay to make it's usage universal
Additionally it contains unique for that player informations like:
- Team
- Color
- Timer values
"""


var bot_engine : AIInterface

## occupier identifies who uses this slot [br]
## its an `int` or a `String` [br]
## `int` -> AI level eg. 1 [br]
## `String == ""` -> we (local player) [br]
## `String != ""` -> remote player with specified network name [br]
var occupier = ""


## used for some simpleness at player in world
var index : int = -1

var team : int = -1  # gets assigned at IM func: _prepare_to_start_game

#TODO create a more universal timer for players that will perform well both in battle and in world
#TODO create a more universal timer for players that will perform well both in battle and in world
var timer_reserve_sec : int = CFG.CHESS_CLOCK_BATTLE_TIME_PER_PLAYER_MS
var timer_increment_sec : int = CFG.CHESS_CLOCK_BATTLE_TURN_INCREMENT_MS

## index of color see `CFG.TEAM_COLORS`
var color_idx : int = 0


static func create(new_slot : Slot) -> Player:
	var result := Player.new()

	if new_slot.is_bot():
		assert(FileAccess.file_exists(new_slot.battle_bot_path),
			   "File for bot '%s' does not exist" % [new_slot.battle_bot_path])
		result.bot_engine = load(new_slot.battle_bot_path).instantiate()
		assert(result.bot_engine != null, "Bot '%s' does not exist" % new_slot.battle_bot_path)
		result.add_child(result.bot_engine)
		result.bot_engine.set_player(result)

	result.name = "Player_" + result.get_player_name()
	result.index = new_slot.index
	result.team = new_slot.team
	result.color_idx = new_slot.color_idx

	result.occupier = new_slot.occupier

	result.timer_reserve_sec = new_slot.timer_reserve_sec
	result.timer_increment_sec = new_slot.timer_increment_sec
	result.index = new_slot.index
	result.team = new_slot.team
	result.color_idx = new_slot.color_idx

	result.occupier = new_slot.occupier

	result.timer_reserve_sec = new_slot.timer_reserve_sec
	result.timer_increment_sec = new_slot.timer_increment_sec

	return result


static func create_for_tutorial(player_index : int, battle_bot_path : String = "") -> Player:
	var result := Player.new()

	if battle_bot_path.length() == 0:
		result.name = "Player"
		result.occupier = ""
	else:
		result.name = "AI"
		result.occupier = 1  # TODO assign a proper difficulty rating

		result.bot_engine = load(battle_bot_path).instantiate()

		assert(result.bot_engine, "Bot '%s' does not exist" % battle_bot_path)

		result.add_child(result.bot_engine)
		result.bot_engine.set_player(result)


	result.index = player_index
	result.team = player_index
	result.color_idx = player_index

	return result



#region Getters

func is_local() -> bool:
	return occupier is String and occupier.is_empty()


func get_player_name() -> String:
	# TODO make these names same as elsewhere
	if bot_engine:
		return "AI"
	if is_local():
		return "LOCAL" # TODO use the same identifier which is "(( you ))" when
					   # offline
	# network login
	return occupier


func get_player_color() -> DataPlayerColor:
	return CFG.TEAM_COLORS[color_idx]


## 2 line string - Player color | controller name
func get_full_player_description() -> String:
	return "%s\n%s" % [get_player_color().name, get_player_name()]

#endregion Getters


## let player know its his turn,
## in case play is AI, call his decision maker
func your_turn(battle_state : BattleGridState) -> void:
	var color_name = CFG.TEAM_COLORS[color_idx].name
	print("your move %s - %s" % [get_player_name(), color_name])

	if bot_engine and not NET.client: # AI is simulated on server only
		bot_engine.play_move(battle_state)


func _get_bot_name(all_slots : Array[Slot]) -> String:
	var number_of_ais : int = 0
	var index_of_this_ai : int = 0
	for slot in all_slots:
		if slot.is_bot():
			if slot == self:
				index_of_this_ai = number_of_ais
			number_of_ais += 1
	if number_of_ais == 1:
		return "AI"
	return "AI %s" % index_of_this_ai
