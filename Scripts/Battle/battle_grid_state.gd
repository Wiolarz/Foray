class_name BattleGridState
extends GenericHexGrid

const STATE_SUMMONNING = "summonning"
const STATE_FIGHTING = "fighting"
const STATE_SACRIFICE = "sacrifice"
const STATE_BATTLE_FINISHED = "battle_finished"

const MOVE_IS_INVALID = -1

const STALEMATE_TURN_REPEATS = 2  # number of repeated moves that fast forward Mana Cyclon Timer

var state : String = STATE_SUMMONNING
var turn_counter : int = 0
var current_army_index : int = 0
var armies_in_battle_state : Array[ArmyInBattleState] = []

var currently_processed_move_info : MoveInfo = null
var currently_active_unit : Unit = null

var number_of_mana_wells : int = 0
var cyclone_target : ArmyInBattleState


#region init

func _init(width_ : int, height_ : int):
	super(width_, height_, BattleHex.sentinel)


static func create(map : DataBattleMap, new_armies : Array[Army]) -> BattleGridState:
	var result := BattleGridState.new(map.grid_width, map.grid_height)

	# assigning players without a team
	var occupied_team_slots = []
	for army in new_armies: 
		var team = army.controller.team
		if team == 0:
			continue
		if team not in occupied_team_slots:
			occupied_team_slots.append(team)
	var new_team_idx = 1
	for army in new_armies:
		var team = army.controller.team
		if team == 0:
			while new_team_idx in occupied_team_slots:
				new_team_idx += 1
			army.controller.team = new_team_idx
			new_team_idx += 1
	
	# generate ArmyInBattleState Objects
	for army in new_armies:
		result.armies_in_battle_state.append(ArmyInBattleState.create_from(army, result))

	# generate battle hex tiles using GenericHexGrid variables
	for x in range(map.grid_width):
		for y in range(map.grid_height):
			var map_tile : DataTile = map.grid_data[x][y]
			var new_hex := BattleHex.create(map_tile)
			result.set_hex(Vector2i(x,y), new_hex)

			if new_hex and new_hex.is_mana_tile(): # MANA
				result.number_of_mana_wells += 1

	result.mana_values_changed() # assign first cyclone target

	return result

#endregion init


#region move_info support

## Unpacker of MoveInfo class [br]
## returns Unit (RefCounted) to the BM for there to be created Node2D object
func move_info_summon_unit(move_info : MoveInfo) -> Unit:
	assert(move_info.move_type == MoveInfo.TYPE_SUMMON)
	currently_processed_move_info = move_info
	var unit_data := move_info.summon_unit
	var coord := move_info.target_tile_coord
	var initial_rotation := _get_spawn_rotation(coord)
	var army_state := armies_in_battle_state[current_army_index]
	var unit := army_state.summon_unit(unit_data, coord, initial_rotation)
	move_info.army_idx = current_army_index
	move_info.original_rotation = initial_rotation

	_put_unit_on_grid(unit, coord)
	_switch_participant_turn()
	currently_processed_move_info = null
	return unit


## Unpacker of MoveInfo class [br]
## Calls specific methods based on 'move_info.move_type'
func move_info_execute(move_info : MoveInfo) -> void:
	currently_processed_move_info = move_info
	
	var source_tile_coord := move_info.move_source

	var unit = get_unit(source_tile_coord)
	currently_active_unit = unit #TEMP verify where you have to reset this value


	match move_info.move_type:
		MoveInfo.TYPE_MOVE:
			var target_tile_coord := move_info.target_tile_coord
			var direction = GenericHexGrid.direction_to_adjacent(unit.coord, target_tile_coord)

			move_info.register_move_start(current_army_index, unit)
			_perform_move(unit, direction, target_tile_coord)
			move_info.register_whole_move_complete()

		MoveInfo.TYPE_SACRIFICE:
			turn_counter -= 1 #TEMP? Doesn't move the turn counter
			move_info.register_kill(_get_army_index(cyclone_target), unit)

			_kill_unit(unit)
		
		MoveInfo.TYPE_MAGIC:
			var target_tile_coord := move_info.target_tile_coord
			var spell = move_info.spell
			
			move_info.register_move_start(current_army_index, unit) # undo related

			_perform_magic(unit, target_tile_coord, spell) # KEY FUNCTION

			move_info.register_whole_move_complete() # TEMP check what it was supposed to do
			
	turn_counter += 1
	currently_processed_move_info = null

	
	_check_battle_end()
	if battle_is_ongoing():
		_switch_participant_turn()

#endregion move_info support


#region Undo

## used only by BM.undo()
## returns array of revived units
func undo(move_info : MoveInfo) -> Array[Unit]:
	var result : Array[Unit] = []
	if move_info.move_type == MoveInfo.TYPE_SUMMON:
		current_army_index = move_info.army_idx
		armies_in_battle_state[current_army_index].unsummon(move_info.target_tile_coord)
		state = STATE_SUMMONNING

	if move_info.move_type == MoveInfo.TYPE_MOVE:
		# revert turn change
		current_army_index = move_info.army_idx
		turn_counter -= 1

		var actions_to_undo = move_info.actions_list.duplicate()
		# last action should be reversed first, else bugs will be created
		actions_to_undo.reverse()
		for a in actions_to_undo:
			if a is MoveInfo.KilledUnit:
				var u = _undo_kill(move_info, a)
				result.append(u)
			elif a is MoveInfo.PushedUnit:
				_undo_push(move_info, a)
			elif a is MoveInfo.LocomotionCompleted:
				_undo_main_locomotion(move_info)
			else :
				push_error("unknown action type %s - %s"%[a.get_class(), str(a)])

		# revert turn
		var unit := get_unit(move_info.move_source)
		unit.turn(move_info.original_rotation)

	return result


func _undo_main_locomotion(move_info : MoveInfo) -> void:
	var m_unit := get_unit(move_info.target_tile_coord)
	_change_unit_coord(m_unit, move_info.move_source)
	var m_hex = _get_battle_hex(move_info.move_source)
	m_unit.move(move_info.move_source, m_hex.swamp)


func _undo_kill(_move: MoveInfo , killed : MoveInfo.KilledUnit) -> Unit:
	var u := armies_in_battle_state[killed.army_idx].revive(killed)
	_put_unit_on_grid(u, u.coord)
	return u


func _undo_push(_move : MoveInfo , pushed : MoveInfo.PushedUnit) -> void:
	var p_unit := get_unit(pushed.to_coord)
	_change_unit_coord(p_unit, pushed.from_coord)
	var p_hex = _get_battle_hex(pushed.from_coord)
	p_unit.move(pushed.from_coord, p_hex.swamp)

#endregion Undo


#region Symbols

## returns true when unit should stop processing further steps
## it died or battle ended
func _process_symbols(unit : Unit) -> bool:
	if _should_die_to_counter_attack(unit):
		_kill_unit(unit)
		return true
	_process_offensive_symbols(unit)
	if not battle_is_ongoing():
		return true
	return false


func _should_die_to_counter_attack(unit : Unit) -> bool:
	# Returns true if Enemy counter_attack can kill the target
	var adjacent_units = _get_adjacent_units(unit.coord)

	for side in range(6):
		if not adjacent_units[side]:
			continue # no unit
		if adjacent_units[side].controller.team == unit.controller.team:
			continue # no friendly fire within team
		
		var shield_power : int = Unit.defense_power(unit.get_symbol(side))
		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_symbol : E.Symbols = adjacent_units[side].get_symbol(opposite_side)
		match enemy_symbol:
			E.Symbols.SPEAR, E.Symbols.STRONG_SPEAR: # enemy has a counter_attack
				if Unit.attack_power(enemy_symbol) > shield_power:
					return true
		
	return false


func _process_offensive_symbols(unit : Unit) -> void:
	var adjacent := _get_adjacent_units(unit.coord)

	for side in range(6):
		var unit_weapon = unit.get_symbol(side)
		if unit_weapon in [E.Symbols.EMPTY, E.Symbols.SHIELD]:
			continue # We don't have any weapon
		if unit_weapon == E.Symbols.BOW:
			_process_bow(unit, side)
			continue # bow is special case
		if not adjacent[side]:
			continue # nothing to interact with
		if adjacent[side].controller.team == unit.controller.team:
			continue # no friendly fire within team

		var enemy = adjacent[side]
		if unit_weapon == E.Symbols.PUSH:
			_push_enemy(enemy, side)
			continue # push is special case
		var opposite_side := GenericHexGrid.opposite_direction(side)
		if Unit.defense_power(enemy.get_symbol(opposite_side)) >= Unit.attack_power(unit_weapon):
			continue # enemy defended
		_kill_unit(enemy)


func _process_bow(unit : Unit, side : int) -> void:
	var target := _get_shot_target(unit.coord, side)

	if target == null:
		return # no target
	if target.controller.team == unit.controller.team:
		return # no friendly fire within team

	var opposite_side := GenericHexGrid.opposite_direction(side)
	var shield_power : int = Unit.defense_power(target.get_symbol(opposite_side))
	if Unit.attack_power(unit.get_symbol(side)) <= shield_power:
		return  # blocked by shield

	_kill_unit(target)


func _push_enemy(enemy : Unit, direction : int) -> void:
	var target_coord := GenericHexGrid.distant_coord(enemy.coord, direction, 1)

	if not _is_movable(target_coord):
		# Pushing outside the map
		_kill_unit(enemy)
		return

	var target := get_unit(target_coord)
	if target != null:
		# Spot isn't empty
		_kill_unit(enemy)
		return

	currently_processed_move_info.register_push(enemy, target_coord)

	# MOVE for PUSH (no rotate)
	_change_unit_coord(enemy, target_coord)
	enemy.move(target_coord, _get_battle_hex(target_coord).swamp)

	# check for counter_attacks
	if _should_die_to_counter_attack(enemy):
		_kill_unit(enemy)

#endregion Symbols


#region public helpers

func get_current_player() -> Player:
	return armies_in_battle_state[current_army_index].army_reference.controller


func get_unit(coord : Vector2i) -> Unit:
	return _get_battle_hex(coord).unit


func is_move_valid(unit : Unit, coord : Vector2i) -> bool:
	return _get_move_direction_if_valid(unit, coord) != MOVE_IS_INVALID


func is_during_summoning_phase() -> bool:
	return state == STATE_SUMMONNING

#endregion public helpers


#region private helpers

func _get_battle_hex(coord : Vector2i) -> BattleHex:
	return get_hex(coord)


func _is_movable(coord : Vector2i) -> bool:
	return _get_battle_hex(coord).can_be_moved_to


func _get_adjacent_units(coord : Vector2i) -> Array[Unit]:
	var result : Array[Unit] = []
	for dir in range(6):
		var target_coord := GenericHexGrid.adjacent_coord(coord, dir)
		result.append(get_unit(target_coord))
	return result


func _get_shot_target(coord : Vector2i, direction : int) -> Unit:
	var target_coord := GenericHexGrid.adjacent_coord(coord, direction)
	var hex := _get_battle_hex(target_coord)
	while not hex.unit and not hex.blocks_shots():
		target_coord = GenericHexGrid.adjacent_coord(target_coord, direction)
		hex = _get_battle_hex(target_coord)
	return hex.unit


## Checks if given tile relative to start tile is in specific direction within specific range [br]
## start_tile, end_tile | direction = -1 search in all directions| reach = -1 with that value searh till the end of board
func _is_faced_tile_in_range(start_coord : Vector2i, end_coord : Vector2i, direction : int, reach : int = -1) -> bool:
	for angle in range(6):
		var tile : Vector2i = start_coord
		if direction != -1:
			angle = direction
		var idx = 0
		while idx < reach:
			idx += 1
			tile += DIRECTION_TO_OFFSET[angle]
			if tile == end_coord:
				return true
	return false


## Returns `MOVE_IS_INVALID` if move is incorrect
## or a turn direction `E.GridDirections` if move is correct
func _get_move_direction_if_valid(unit : Unit, coord : Vector2i) -> int:
	"""
		For move to be valid, target coord
		- is a neighbor of the unit
		- allows movement
		- can be occupied by a new unit:
			- is empty
			- contains a unit that would be killed/pushed by the move

		@param unit to move
		@param coord target coord for unit to move to
		@return MOVE_IS_INVALID (-1) if move is illegal, direction otherwise
	"""

	var move_direction := GenericHexGrid.direction_to_adjacent(unit.coord, coord)
	# not adjacent
	if move_direction == TILES_NOT_ADJACENT:
		return MOVE_IS_INVALID

	var hex = _get_battle_hex(coord)
	if not hex.can_be_moved_to:
		return MOVE_IS_INVALID

	var unit_on_target = hex.unit
	# empty field
	if not unit_on_target:
		return move_direction

	if not _can_kill_or_push(unit, unit_on_target, move_direction):
		return MOVE_IS_INVALID

	return move_direction


## can i kill/push this enemy in melee if i attack in specified direction
func _can_kill_or_push(me : Unit, other_unit : Unit, attack_direction : int):
	# - attacker has no attack symbol on front
	# - attacker has push symbol on front (no current unit has it)
	# - attacker has some attack symbol
	#   - defender has shield

	if other_unit.controller == me.controller:
		return false
	elif other_unit.controller.team == me.controller.team:
		return false

	var front_symbol : E.Symbols = me.get_front_symbol()
	match front_symbol:
		E.Symbols.EMPTY:
			# can't deal with enemy_unit
			return false
		E.Symbols.SHIELD:
			# can't deal with enemy_unit
			return false
		E.Symbols.PUSH:
			# push ignores enemy_unit shields etc
			return true
		_:
			# assume other attack symbol
			# Does enemy_unit has a shield?
			var defense_direction = GenericHexGrid.opposite_direction(attack_direction)
			var shield_power = Unit.defense_power(other_unit.get_symbol(defense_direction))

			if shield_power >= Unit.attack_power(front_symbol):
				return false
			# no shield, attack ok
			return true


func _get_player_army(player : Player) -> BattleGridState.ArmyInBattleState:
	for army in armies_in_battle_state:
		if army.army_reference.controller == player:
			return army
	assert(false, "No army for player " + str(player))
	return null


func _get_army_index(army : BattleGridState.ArmyInBattleState):
	var result = armies_in_battle_state.find(army)
	return result

#endregion private helpers


#region Gameplay Events

## IMPORTANT occurs every turn -> main way to change state
func _switch_participant_turn() -> void:
	var prev_player := armies_in_battle_state[current_army_index]
	var prev_idx = current_army_index
	current_army_index += 1
	current_army_index %= armies_in_battle_state.size()
	print(NET.get_role_name(), " _switch_participant_turn ", current_army_index)

	match state:
		STATE_SUMMONNING:
			var skip_count = 0
			# skip players with nothing to summon
			while armies_in_battle_state[current_army_index].units_to_summon.size() == 0:
				current_army_index += 1
				current_army_index %= armies_in_battle_state.size()
				skip_count += 1
				# no player has anything to summon, go to next phase
				if skip_count == armies_in_battle_state.size():
					state = STATE_FIGHTING
					current_army_index = 0  # first army is always present
					break

		STATE_FIGHTING:
			while not armies_in_battle_state[current_army_index].can_fight():
				current_army_index += 1
				current_army_index %= armies_in_battle_state.size()

			if prev_idx > current_army_index: # Cyclone timer update
				cyclone_target.cyclone_timer -= 1

				if cyclone_target.cyclone_timer == 0:
					current_army_index = _get_army_index(cyclone_target)
					state = STATE_SACRIFICE
	
		STATE_SACRIFICE:  # New turn starts
			current_army_index = 0  # first army may no longer be present
			while not armies_in_battle_state[current_army_index].can_fight():
				current_army_index += 1
				current_army_index %= armies_in_battle_state.size()
			state = STATE_FIGHTING

	var next_player := armies_in_battle_state[current_army_index]
	# chess clock is updated in turn_ended() and turn_started()
	prev_player.turn_ended()
	next_player.turn_started()


## Basic Unit move:
## unit - that is going to move | direction - it will move toward
## target_title_coord - hex tile it's going to move toward (doesn't have to be adjacent)
func _perform_move(unit : Unit, direction : int, target_tile_coord : Vector2i) -> void:
	# TURN
	unit.turn(direction)
	if _process_symbols(unit):
		return
	currently_processed_move_info.register_turning_complete()
	# MOVE
	_change_unit_coord(unit, target_tile_coord)
	unit.move(target_tile_coord, _get_battle_hex(target_tile_coord).swamp)
	currently_processed_move_info.register_locomote_complete()
	if _process_symbols(unit):
		return


## Spell effect:
## unit - that is going to move |
## target_title_coord - hex tile it's going to move toward (doesn't have to be adjacent)
##  direction - 
func _perform_teleport(unit : Unit, target_tile_coord : Vector2i, direction : int = -1) -> void:
	# TURN
	if direction != -1:
		unit.turn(direction)
		# No need to chceck for counter damage here as rotation happens
		# "during" teleport so we care only about counter damage once we arrive
		currently_processed_move_info.register_turning_complete()
	# MOVE
	_change_unit_coord(unit, target_tile_coord)
	unit.move(target_tile_coord, _get_battle_hex(target_tile_coord).swamp)
	currently_processed_move_info.register_locomote_complete()
	if _process_symbols(unit):
		return


## changes coordinates of the unit ONLY (doesn't activate attack or anything like that)
func _change_unit_coord(unit : Unit, target_coord : Vector2i) -> void:
	_remove_unit(unit)
	_put_unit_on_grid(unit, target_coord)


## Used for movement, kills, unsummon(undo) [br]
## removes Unit from logic hex tile
func _remove_unit(unit : Unit) -> void:
	var hex := _get_battle_hex(unit.coord)
	assert(hex.unit == unit, "incorrect remove unit, coord desync")
	hex.unit = null


## Main kill unit function -> checks for end of battle
## Contains spells related logic
func _kill_unit(target : Unit) -> void:
	var target_army_index := _find_army_idx(target.controller)
	var target_army = _get_player_army(target.controller)

	# check magic to confirm if it dies
	var replaced_target : Unit = null
	var new_target_pos : Vector2i
	for spell in target.effects:
		#spell.enchanted_unit_dies()
		match spell.name:
			"Martyr":
				for unit in target_army.units:
					if replaced_target:
						break
					for ally_spell in unit.effects:
						if ally_spell.name == "Martyr":
							replaced_target = target
							target = unit
							new_target_pos = unit.coord
							break
							
	currently_processed_move_info.register_kill(target_army_index, target)

	# killing starts
	target_army.kill_unit(target)
	_remove_unit(target) # remove reference from hextile
	target.unit_killed() # emit singal for visual death animation

	# verify battle has ended before any additonal spell effects take place
	_check_battle_end()
	if not battle_is_ongoing(): 
		return

	if replaced_target: # "Martyr" spell quick hack
		_perform_teleport(replaced_target, new_target_pos)

	# trigger any post death spell efefect
	for spell in target.effects:
		#spell.enchanted_unit_dies()
		match spell.name:
			"Vengeance":
				#TODO check if this temp solution should be used
				_kill_unit(currently_active_unit)

			_:
				continue
	
	mana_values_changed() # TEMP occurs every time after death

## Rare event when all players repeated their moves -> it pushes cyclone timer to activate next turn
func end_stalemate() -> void:
	print("END OFF STALEMATE")
	cyclone_target.cyclone_timer = 1

#endregion Gameplay Events


#region Summon Phase

func current_player_can_summon_on(coord : Vector2i) -> bool:
	return _can_summon_on(current_army_index, coord)


func _can_summon_on(army_idx : int, coord : Vector2i) -> bool:
	var hex := _get_battle_hex(coord)
	return  hex.spawn_point_army_idx == army_idx and hex.unit == null


func _get_spawn_rotation(coord : Vector2i) -> int:
	return _get_battle_hex(coord).spawn_direction


func _put_unit_on_grid(unit : Unit, coord : Vector2i) -> void:
	var hex := _get_battle_hex(coord)
	assert(hex.can_be_moved_to, "summoning unit to an invalid tile")
	assert(not hex.unit, "summoning unit to an occupied tile")
	hex.unit = unit

#endregion Summon Phase


#region Timer

## in miliseconds -- called only by BM _check_clock_timer_tick()
func get_current_time_left() -> int:
	return armies_in_battle_state[current_army_index].get_time_left_ms()


## only for Replays
func set_displayed_time_left_ms(time_left_ms : int) -> void:
	armies_in_battle_state[current_army_index].set_time_left_ms(time_left_ms)

#endregion Timer


#region Mana Cyclone Timer

## Occurs any time a unit is killed [br]
## It may change the cyclone_target
func mana_values_changed() -> void:
	var current_worst = armies_in_battle_state[0]
	var current_best = armies_in_battle_state[-1]

	# player later in an array win on ties between mana values - it's intentional
	for army in armies_in_battle_state:
		if current_worst.mana_points > army.mana_points: 
			current_worst = army
		if current_best.mana_points < army.mana_points:
			current_best = army
	
	cyclone_target = current_worst
	var mana_difference = current_best.mana_points - current_worst.mana_points
 
	var new_cylone_counter = (number_of_mana_wells * 10) * max(1, (5 - mana_difference))
	#new_cylone_counter = 1 # use to test

	if current_worst.cyclone_timer == 0:  # Cycle killed a unit now it resets
		current_worst.cyclone_timer = new_cylone_counter
	elif current_worst.cyclone_timer > new_cylone_counter:
		current_worst.cyclone_timer = new_cylone_counter

	
func cyclone_get_current_target() -> Player:
	return cyclone_target.army_reference.controller


func cyclone_get_current_target_turns_left() -> int:
	return cyclone_target.cyclone_timer


#endregion Mana Cyclone Timer


#region Magic

## verify if spell can be casted
func is_spell_target_valid(unit : Unit, coord : Vector2i, spell : BattleSpell) -> bool:

	match spell.name:
		"Vengeance", "Shield": # any ally unit
			var target = get_unit(coord)
			if target and target.controller == unit.controller:
				return true
		"Martyr": # ally unit, but not the caster
			var target = get_unit(coord)
			if target and target.controller == unit.controller and target != unit:
				return true
		"Fireball": # any hex target is valid
			return true
		"Teleport": # tile in range that is in front of the caster
			if _is_faced_tile_in_range(unit.coord, coord, unit.unit_rotation, 3):
				return true
		_:
			printerr("Spell targeting not supported: ", spell.name)
			return false

	return false #TEMP

## spell takes an effect
func _perform_magic(unit : Unit, target_tile_coord : Vector2i, spell : BattleSpell) -> void:

	match spell.name:
		"Vengeance":
			get_unit(target_tile_coord).effects.append(spell)
			print(get_unit(target_tile_coord).effects)
		
		"Martyr":
			unit.effects.append(spell)  # target as well as caster both get affected
			get_unit(target_tile_coord).effects.append(spell)
			print(get_unit(target_tile_coord).effects)
		
		"Fireball":
			var enemy_targets : Array[Unit] = []
			var ally_targets : Array[Unit] = []
			var target : Unit = get_unit(target_tile_coord)
			if target and target.controller.team == unit.controller.team:
				ally_targets.append(target)
			elif target:
				enemy_targets.append(target)
			for direction in DIRECTION_TO_OFFSET:
				target = get_unit(target_tile_coord + direction)
				if target and target.controller.team == unit.controller.team:
					ally_targets.append(target)
				elif target:
					enemy_targets.append(target)
			
			for enemy_unit in enemy_targets: # kill enemy units first
				_kill_unit(enemy_unit)
			
			# we only start killing ally units after we are sure battle didn't end yet
			if not battle_is_ongoing():
				return

			for ally_unit in ally_targets: # kill rest
				_kill_unit(ally_unit)
			
		"Teleport":
			_perform_teleport(unit, target_tile_coord)
		
		_:
			printerr("Spell perform not supported: ", spell.name)
			return

	unit.spells.erase(spell) # Remove to test casting multiple times

#endregion Magic


#region End Battle

func _kill_army(army_idx : int):
	armies_in_battle_state[army_idx].kill_army()
	_check_battle_end()


func battle_is_ongoing() -> bool:
	return state != STATE_BATTLE_FINISHED


func _check_battle_end() -> void:
	if state == STATE_BATTLE_FINISHED:
		return

	var teams_alive = []
	for army in armies_in_battle_state:
		if army.can_fight():
			var army_team = army.army_reference.controller.team
			if army_team not in teams_alive:
				teams_alive.append(army_team)

	if teams_alive.size() < 2:
		state = STATE_BATTLE_FINISHED
		return


func force_win_battle():
	for army_idx in range(armies_in_battle_state.size()):
		if army_idx == current_army_index:
			continue
		_kill_army(army_idx)


func surrender_on_timeout():
	_kill_army(current_army_index)


func force_surrender():
	for army_idx in range(armies_in_battle_state.size()):
		if army_idx != current_army_index:
			continue
		_kill_army(army_idx)

#endregion End Battle


#region AI Helpers

func get_possible_moves() -> Array[MoveInfo]:
	if is_during_summoning_phase():
		return _get_all_spawn_moves()

	return _get_all_unit_moves()


func _get_summon_tiles(player : Player) -> Array[Vector2i]:
	var army_idx = _find_army_idx(player)
	var result : Array[Vector2i] = []
	for x in range(width):
		for y in range(height):
			var coord := Vector2i(x,y)
			if _can_summon_on(army_idx, coord):
				result.append(coord)
	return result


func _get_not_summoned_units(player : Player) -> Array[DataUnit]:
	for a in armies_in_battle_state:
		if a.army_reference.controller == player:
			return a.units_to_summon.duplicate()
	assert(false, "ai asked for units to summon but it doesn't control any army")
	return []


func _get_units(player : Player) -> Array[Unit]:
	var idx = _find_army_idx(player)
	return armies_in_battle_state[idx].units


func _find_army_idx(player : Player) -> int:
	for idx in range(armies_in_battle_state.size()):
		if armies_in_battle_state[idx].army_reference.controller == player:
			return idx
	assert(false, "ai asked for army idx for player who doesnt control any army")
	return -1


## not summons, only units already placed
func _get_all_unit_moves() -> Array[MoveInfo]:
	var legal_moves : Array[MoveInfo] = []
	var my_units := _get_units(get_current_player())

	for unit in my_units:
		for side in range(6):
			var new_coord = GenericHexGrid.adjacent_coord(unit.coord, side)
			var move_dir = _get_move_direction_if_valid(unit, new_coord)
			if move_dir != BattleGridState.MOVE_IS_INVALID:
				legal_moves.append(MoveInfo.make_move(unit.coord, new_coord))
	return legal_moves


func _get_all_spawn_moves() -> Array[MoveInfo]:
	var legal_moves: Array[MoveInfo] = []
	var me = get_current_player()
	var spawn_tiles = _get_summon_tiles(me)
	var units = _get_not_summoned_units(me)
	for unit in units:
		for spawn_tile in spawn_tiles:
			legal_moves.append(MoveInfo.make_summon(unit, spawn_tile))

	return legal_moves


## only legal moves are supported
func filter_only_kill_moves(all_moves : Array[MoveInfo]) -> Array[MoveInfo]:
	var all_kill_moves : Array[MoveInfo] = []
	for move in all_moves:
		if _is_kill_move(move):
			all_kill_moves.append(move)

	return all_kill_moves


## only legal moves are supported
func _is_kill_move(move : MoveInfo) -> bool:

	if move.move_type != MoveInfo.TYPE_MOVE:
		return false # summons don't kill

	var me = get_current_player()
	var unit_on_target_field = get_unit(move.target_tile_coord)
	if unit_on_target_field != null \
			and unit_on_target_field.controller != me:
		# can move into a unit and kill it
		# if it couldn't move would not be legal
		return true

	# BOW
	var attacker = get_unit(move.move_source)
	var move_direction = GenericHexGrid.direction_to_adjacent( \
			move.move_source, move.target_tile_coord);
	for side in range(6):
		var opposite_side = GenericHexGrid.opposite_direction(side)
		var symbol = attacker.get_symbol_when_rotated(side, move_direction)
		if symbol == E.Symbols.BOW:
			var target : Unit = _get_shot_target(move.move_source, side)
			if target != null and target.controller != me \
					and target.get_symbol(opposite_side) != E.Symbols.SHIELD:
				# can shoot enemy in this direction
				return true

	# check for enemies near new field
	var target_adjacent_units = _get_adjacent_units(move.target_tile_coord)
	# check for enemy spears
	for side in 6:
		var enemy = target_adjacent_units[side]
		if enemy and enemy.controller != me:
			var opposite_side = GenericHexGrid.opposite_direction(side)
			match enemy.get_symbol(opposite_side):
				E.Symbols.SPEAR, E.Symbols.STRONG_SPEAR:
					if attacker.get_symbol_when_rotated(move_direction, side) != E.Symbols.SHIELD:
						# will die to spear befor it can kill, no-go
						return false
	# check for unprotected attacker symbols
	for side in 6:
		var enemy = target_adjacent_units[side]
		if not enemy or enemy.controller == me:
			continue
		# TODO detect killing pushes
		var opposite_side = GenericHexGrid.opposite_direction(side)

		var attack_symbol =  attacker.get_symbol_when_rotated(move_direction, side)
		match attack_symbol:
				E.Symbols.STRONG_SWORD:
					return true

		if enemy.get_symbol(opposite_side) == E.Symbols.SHIELD:
			continue
		
		match attack_symbol:
			E.Symbols.SWORD, E.Symbols.SPEAR:
				return true

	return false

#endregion


#region Subclasses

class BattleHex:
	var unit : Unit
	var spawn_point_army_idx : int = -1
	var spawn_direction : int
	var can_be_moved_to : bool = true
	var can_shoot_through : bool = true
	var swamp : bool = false # TODO REFACTOR THIS NAME
	var mana : bool = false

	static var sentinel: BattleHex = BattleHex.create_sentinel()


	static func get_spawn_direction(army_id:int) -> int:
		match army_id:
			0: return GenericHexGrid.GridDirections.RIGHT
			2: return GenericHexGrid.GridDirections.TOP_RIGHT
			3: return GenericHexGrid.GridDirections.BOTTOM_LEFT
			_: return GenericHexGrid.GridDirections.LEFT


	static func create_sentinel():
		var result = BattleHex.new()
		result.can_be_moved_to = false
		result.can_shoot_through = false
		return result


	static func create(data : DataTile) -> BattleHex:
		if data.type == "sentinel":
			return null

		var result = BattleHex.new()

		if data.type.substr(1) == "_player_spawn":
			result.spawn_point_army_idx = data.type[0].to_int() - 1
			result.spawn_direction = get_spawn_direction(result.spawn_point_army_idx)
			return result


		match data.type:
			"hole":
				result.can_be_moved_to = false
			"wall":
				result.can_be_moved_to = false
				result.can_shoot_through = false
			"swamp":
				result.swamp = true
			"empty":
				pass
			"mana_well":
				result.mana = true
			_:
				pass #TODO push error that tile type is not supported

		return result


	func blocks_shots() -> bool:
		return not can_shoot_through
	

	func is_mana_tile() -> bool:
		return mana


class ArmyInBattleState:
	var battle_grid_state : WeakRef # BattleGridState
	var army_reference : Army

	var units_to_summon : Array[DataUnit] = []
	var units : Array[Unit] = []
	var dead_units : Array[DataUnit] = []

	var mana_points : int = 1
	var cyclone_timer : int = 100

	## when turn started - for local time calculation
	var turn_start_timestamp
	##  miliseconds on the clock when turn started - will be synched in multiplayer
	var start_turn_clock_time_left_ms = CFG.CHESS_CLOCK_BATTLE_TIME_PER_PLAYER_MS
	## time to add when turn ends
	var turn_increment_ms = CFG.CHESS_CLOCK_BATTLE_TURN_INCREMENT_MS


	static func create_from(army : Army, state : BattleGridState) -> ArmyInBattleState:
		var result = ArmyInBattleState.new()
		result.battle_grid_state = weakref(state)
		result.army_reference = army
		for unit : DataUnit in army.units_data:
			result.units_to_summon.append(unit)
			
			result.mana_points += unit.mana # MANA

		result.turn_started() # TEMP - FIXME - better init for chess clock

		return result


	func turn_started() -> void:
		turn_start_timestamp = Time.get_ticks_msec()


	func get_time_left_ms() -> int:
		var turn_time_local_passed_ms = Time.get_ticks_msec() - turn_start_timestamp
		return start_turn_clock_time_left_ms - turn_time_local_passed_ms


	func set_time_left_ms(time_left_ms : int) -> void:
		turn_start_timestamp = Time.get_ticks_msec()
		start_turn_clock_time_left_ms = time_left_ms


	func turn_ended() -> void:
		start_turn_clock_time_left_ms = get_time_left_ms()
		start_turn_clock_time_left_ms += turn_increment_ms

	## Manages unit relation to it's related army object [br]
	## Used in so that "summary"
	func kill_unit(target : Unit) -> void:
		print("killing ", target.coord, " ",target.template.unit_name)
		if target.template.mana > 0:
			mana_points -= target.template.mana
			# mana_value changed gets called after every kill anyway

		units.erase(target)
		dead_units.append(target.template)
		#gdlint: ignore=private-method-call


	func revive(kill_info : MoveInfo.KilledUnit) -> Unit:
		var unit = kill_info.respawn()
		unit.controller = army_reference.controller
		dead_units.erase(unit.template)
		units.append(unit)
		return unit


	func kill_army() -> void:
		dead_units.append_array(units_to_summon)
		units_to_summon.clear()
		for unit_idx in range(units.size() - 1, -1, -1):
			battle_grid_state.get_ref()._kill_unit(units[unit_idx])


	func can_fight() -> bool:
		return units.size() > 0 or units_to_summon.size() > 0


	func summon_unit(unit_data : DataUnit, coord : Vector2i, rotation : int) -> Unit:
		units_to_summon.erase(unit_data)
		var result = Unit.create(army_reference.controller, unit_data, coord, rotation)
		units.append(result)
		return result


	func unsummon(coord : Vector2i):
		var target = battle_grid_state.get_ref().get_unit(coord)
		units.erase(target)
		units_to_summon.append(target.template)
		#gdlint: ignore=private-method-call
		battle_grid_state.get_ref()._remove_unit(target)
		target.unit_killed()

#endregion Subclasses
