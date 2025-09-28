class_name Unit
extends RefCounted # default

signal unit_died()
signal unit_turned()
signal unit_moved()
signal unit_magic_effect(effect : BattleMagicEffect)

const MAX_EFFECTS_PER_UNIT = 2

signal unit_is_shooting(side : int, attacker_coord : Vector2i)
signal unit_is_slashing(side : int)
signal unit_is_pushing(side : int)
signal unit_is_blocking(side : int, attacker_coord : Vector2i)
signal unit_is_counter_attacking(side : int)

signal unit_captured_mana(target_tile : Vector2i)  # change visuals of the tile to mark it as captured


## TODO remove this
var controller : Player :
	get:
		if army_in_battle:
			return IM.get_player_by_index(army_in_battle.army_reference.controller_index)
		return null
## reference to army to which the unit belongs
var army_in_battle : BattleGridState.ArmyInBattleState

## units constant stats resource
var template : DataUnit

## copied unit symbol data, that can be modified by spells/skills
var symbols : Array[DataSymbol]

## coordinates on a battle grid
var coord : Vector2i
## see E.GridDirections, int for convinience
var unit_rotation : int

## unit died
var dead : bool
## is unit created using magic
var summoned : bool = false

## determines if exp can be awarded to the enemy hero
var level : int

## list of spells unit can cast (all of those are one-time use only)
var spells : Array[BattleSpell] = []

## magic effects, size_limit == 2
var effects : Array[BattleMagicEffect] = []

var mana : int = 0

var is_on_swamp : bool = false

# TEMP implementation, should be merged with is_on_swamp and other terrain based effects
## this information is only for visual representation
var is_on_rock : bool = false
var is_on_mana : bool = false

static func create(new_controller : Player, \
		new_template : DataUnit, \
		new_coord : Vector2i, \
		new_rotation : GenericHexGrid.GridDirections, \
		new_army_in_battle_state : BattleGridState.ArmyInBattleState) -> Unit:
	var result = Unit.new()
	result.template = new_template
	result.symbols = new_template.symbols.duplicate(true) # TEMP TODO fix symbols to another type too
	result.level = new_template.level
	result.mana = new_template.mana
	result.summoned = new_template.summoned
	result.spells = new_template.spells.duplicate() # spells reset every battle

	result.controller = new_controller
	result.army_in_battle = new_army_in_battle_state
	result.template = new_template
	result.symbols = new_template.duplicate_symbols()

	result.coord = new_coord
	result.unit_rotation = new_rotation
	return result

#region Emit Animation Signals

## turns unit front to a given side, can be awaited see waits_for_form
func turn(side : GenericHexGrid.GridDirections):
	if side == unit_rotation:
		return
	unit_rotation = side
	print("emit turn [turn]")
	unit_turned.emit()


## puts unit to a given coordinate, can be awaited see waits_for_form
func move(new_coord : Vector2i, battle_tile : BattleGridState.BattleHex):
	is_on_swamp = battle_tile.swamp
	is_on_rock = battle_tile.hill
	is_on_mana = battle_tile.mana
	unit_magic_effect.emit(null)

	var old = coord
	coord = new_coord
	print("emit move [move] %s %s" % [str(old), str(new_coord)])
	unit_moved.emit()


## kills unit, can be awaited see waits_for_form
func unit_killed():
	dead = true
	unit_died.emit()

#endregion Emit Animation Signals


#region Unit Symbols

## gets symbol facing specified directin on the battle map
func get_symbol(side_world : int) -> DataSymbol:
	return get_symbol_when_rotated(side_world, unit_rotation)


## gets symbol facing specified directin on the battle map, if unit was rotated in given dir [br]
## side_world - direction unit is turned toward [br]
## hypotetical_rotation - unit side it's symbol
func get_symbol_when_rotated(side_world : int, hypotetical_rotation : int) -> DataSymbol:
	if is_on_swamp:
		return CFG.EMPTY_SYMBOL
	var side_local : int = GenericHexGrid.rotate_clockwise( \
			side_world as GenericHexGrid.GridDirections, -hypotetical_rotation)
	return symbols[side_local]


func get_front_symbol() -> DataSymbol:
	if is_on_swamp:
		return CFG.EMPTY_SYMBOL
	return symbols[GenericHexGrid.DIRECTION_FRONT]

#endregion Unit Symbols


#region Magic

## attempts to add magical effect to a unit (there is limit of 2) [br]
## returns bool if it was succesful
func try_adding_magic_effect(effect : BattleMagicEffect) -> bool:
	if effects.size() >= MAX_EFFECTS_PER_UNIT:
		return false
	effects.append(effect)
	unit_magic_effect.emit(effect)
	return true


## currently used only to update UI
func effect_state_changed() -> void:
	unit_magic_effect.emit(null)

#endregion Magic
