class_name BattleEventDescription
extends Resource

## Description of the state needs to occur before Text Bubble can show up
## Developer lists all things that need to occur creating a new BattleEventDescription
## which will be compared to current battle state through is_description_satisfied()


#TODO consider generating those events for battle replays, to be compared to with new ones for unit tests

@export_enum(BattleGridState.STATE_FIGHTING,
			BattleGridState.STATE_DEPLOYMENT,
			BattleGridState.STATE_SACRIFICE,
			BattleGridState.STATE_BATTLE_FINISHED) \
			var state_battle_is_in : String = BattleGridState.STATE_FIGHTING

## Default -1 always eligible
@export var current_turn : int = -1

## simple list of unit_name's [br]
## event check will provide freshly dead unit with additional info string and compare to this
@export var dead_units : Array[String] = []

## Index of the player which turn it is: [br]
## 0 - first player [br]
## -1 - any player
@export var current_army_index : int = 0 # -1

## Those variables are not generated automatically during generate_current_battle_event()
## is_description_satisfied() compares manaully selected values from this category
## with the singletons on its own
@export_category("Manually applied")

## Checks singleton, so doesn't care about provided battle state
@export var selected_unit : String


static func generate_current_battle_event(battle_state : BattleGridState, additional_info : String = "") \
	-> BattleEventDescription:
	var result := BattleEventDescription.new()
	result.current_army_index = battle_state.current_army_index
	result.state_battle_is_in = battle_state.state

	result.current_turn = battle_state.turn_counter

	for army : BattleGridState.ArmyInBattleState in battle_state.armies_in_battle_state:
		for dead_unit in army.dead_units:
			result.dead_units.append(dead_unit.unit_name)

	# ADDDITONAL INFO
	if additional_info.length() == 0:
		return result

	var additional_info_translated : PackedStringArray = additional_info.split(" ")
	for pair_idx : int in range(0, additional_info_translated.size(), 2):
		var key : String = additional_info_translated[pair_idx]
		var value : String  = additional_info_translated[pair_idx + 1]

		match key:
			"dies":
				result.dead_units.append(value)

	return result


func _print_reason(debug_note : String) -> void:
	print(resource_name, "||REASON|| -->", debug_note)


## Core functionality for TextBubbles and Battle Events -> It verifies prerequesites. [br]
## Prerequisite Object - BattleEventDescription is provided [br]
## with the description of the current battle state. [br]
## If in its requirements something misalign with the current Battle Event it returns FALSE
func is_description_satisfied(event : BattleEventDescription) -> bool:
	if event.current_army_index != 0:
		return false

	if state_battle_is_in != event.state_battle_is_in:
		_print_reason("wrong phase current =" + event.state_battle_is_in)
		return false

	if current_turn > -1 and current_turn != event.current_turn:
		_print_reason("wrong turn")
		return false

	if dead_units.size() > 0:
		for unit_name : String in dead_units:
			if unit_name not in event.dead_units:
				_print_reason("dead units check" + unit_name + " | " + str(event.dead_units))
				return false

  	# TEMP->TODO discuss if selected unit should be public

	match selected_unit:
		"":  # no set requirement
			pass
		"any":
			if not BM._selected_unit:
				_print_reason("no unit selected")
				return false
		"null":
			if BM._selected_unit:
				_print_reason("some unit was selected")
				return false
		_:  # specfic unit isn't selected
			if not BM._selected_unit:
				_print_reason("no unit selected, required: " + selected_unit)
				return false
			elif selected_unit != BM._selected_unit.template.unit_name:
				_print_reason("wrong unit selected -" +  BM._selected_unit.template.unit_name)
				return false

	return true
