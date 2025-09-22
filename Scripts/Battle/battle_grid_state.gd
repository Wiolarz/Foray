class_name BattleGridState
extends GenericHexGrid

enum MoveConsequences {
	NONE,
	KILL,
	DEATH,
	KAMIKAZE # Both kills and dies
}

const STATE_DEPLOYMENT = "deployment"
const STATE_FIGHTING = "fighting"
const STATE_SACRIFICE = "sacrifice"
const STATE_BATTLE_FINISHED = "battle_finished"

const MOVE_IS_INVALID = -1

## BM._check_for_stalemate() doesn't yet handle bigger number of allowed repeats than 2
const STALEMATE_TURN_REPEATS = 2  # number of repeated moves that fast forward Mana Cyclon Timer

var state : String = STATE_DEPLOYMENT

## Visible to players counter which works alongside Mana Cyclone system [br]
## Is incremented after units move/cast_a_spell -> Doesn't after unit placement/sacrifice
var turn_counter : int = 0
var current_army_index : int = 0
var armies_in_battle_state : Array[ArmyInBattleState] = []

var currently_processed_move_info : MoveInfo = null
var currently_active_unit : Unit = null

var number_of_mana_wells : int = 0
var cyclone_target : ArmyInBattleState
const MANA_WELL_POWER : int = 5

#TEMP HACK for proper awarding of exp in spear kills
var spear_holding_killer_teams : Array[int] = []


var stalemate_failsafe_on : bool = false
var stalemate_failsafe_start : int = 0

#region init

func _init(width_ : int, height_ : int):
	super(width_, height_, BattleHex.sentinel)


static func create(map : DataBattleMap, new_armies : Array[Army]) -> BattleGridState:
	var result := BattleGridState.new(map.grid_width, map.grid_height)

	for army : Army in new_armies:
		var new_army_in_battle := ArmyInBattleState.create_from(army, result)
		var player := IM.get_player_by_index(army.controller_index)
		new_army_in_battle.team = player.team  # shortcut, to make
		result.armies_in_battle_state.append(new_army_in_battle)




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
func move_info_deploy_unit(move_info : MoveInfo) -> Unit:
	assert(move_info.move_type == MoveInfo.TYPE_DEPLOY)
	currently_processed_move_info = move_info
	var unit_data := move_info.deployed_unit
	var coord := move_info.target_tile_coord
	var initial_rotation := _get_deploy_rotation(coord)
	var army_state := armies_in_battle_state[current_army_index]
	var unit := army_state.deploy_unit(unit_data, coord, initial_rotation)
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

	# BMFast integrity check - live testing purposes only
	var bmfast = BattleManagerFast.from(self)
	bmfast.check_integrity_before_move(self, move_info)

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

	if stalemate_failsafe_on and stalemate_failsafe_start + 6 < turn_counter:
		for army in armies_in_battle_state:
			for _unit in army.units:
				if _unit.template.unit_name != "orc_2": continue

				var vengeance_effect : BattleMagicEffect = \
					load("res://Resources/Battle/Battle_Spells/Battle_Magic_Effects/vengeance_effect.tres")

				vengeance_effect.apply_effect(_unit, "post death spell effect")

	_check_battle_end()
	if battle_is_ongoing():
		_switch_participant_turn()

	currently_processed_move_info = null

	# BMFast integrity check contd. - live testing purposes only
	bmfast.check_integrity_after_move(self)


#endregion move_info support


#region Undo


## used only by BM.undo()
## returns array of revived units
func undo(move_info : MoveInfo) -> Array[Unit]:
	var killed_units : Array[Unit] = []
	if move_info.move_type == MoveInfo.TYPE_DEPLOY:
		current_army_index = move_info.army_idx
		armies_in_battle_state[current_army_index].undeploy(move_info.target_tile_coord)
		state = STATE_DEPLOYMENT

	if move_info.move_type == MoveInfo.TYPE_MOVE:
		# revert turn change
		current_army_index = move_info.army_idx
		turn_counter -= 1

		var actions_to_undo = move_info.actions_list.duplicate()
		# last action should be reversed first, else bugs will be created
		actions_to_undo.reverse()
		for action in actions_to_undo:
			if action is MoveInfo.KilledUnit:
				var killed_unit = _undo_kill(move_info, action)
				killed_units.append(killed_unit)
			elif action is MoveInfo.PushedUnit:
				_undo_push(move_info, action)
			elif action is MoveInfo.LocomotionCompleted:
				_undo_main_locomotion(move_info)
			else :
				push_error("unknown action type %s - %s"%[action.get_class(), str(action)])

		# revert turn
		var unit := get_unit(move_info.move_source)
		unit.turn(move_info.original_rotation)

	return killed_units


func _undo_main_locomotion(move_info : MoveInfo) -> void:
	var m_unit := get_unit(move_info.target_tile_coord)
	_change_unit_coord(m_unit, move_info.move_source)
	var m_hex = _get_battle_hex(move_info.move_source)
	m_unit.move(move_info.move_source, m_hex)


func _undo_kill(_move : MoveInfo , killed : MoveInfo.KilledUnit) -> Unit:
	var unit : Unit = armies_in_battle_state[killed.army_idx].revive(killed)
	_put_unit_on_grid(unit, unit.coord)
	return unit


func _undo_push(_move : MoveInfo , pushed : MoveInfo.PushedUnit) -> void:
	var p_unit := get_unit(pushed.to_coord)
	_change_unit_coord(p_unit, pushed.from_coord)
	var p_hex = _get_battle_hex(pushed.from_coord)
	p_unit.move(pushed.from_coord, p_hex)

#endregion Undo


#region Symbols

## returns true when unit should stop processing further steps
## it died or battle ended
func _process_symbols(unit : Unit, move_type : E.MoveType) -> bool:
	if _should_die_to_counter_attack(unit):
		_kill_unit(unit)
		return true
	_process_offensive_symbols(unit, move_type)
	if not battle_is_ongoing():
		return true
	return false


## Returns true if Enemy counter_attack can kill the target [br]
## Starts animation for stabbing in case
func _should_die_to_counter_attack(unit : Unit) -> bool:
	spear_holding_killer_teams = [] #TEMP

	var adjacent_units = _get_adjacent_units(unit.coord)

	for side in range(6):
		var enemy = adjacent_units[side]
		if not enemy:
			continue # no unit
		if enemy.army_in_battle.team == unit.army_in_battle.team:
			continue # no friendly fire within team
		var unit_symbol : DataSymbol = unit.get_symbol(side)
		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_symbol : DataSymbol = enemy.get_symbol(opposite_side)

		if not enemy_symbol.counter_attack:
			continue  # Counter Attack doesn't even occur
		if unit_symbol.does_parry(enemy_symbol):
			unit.unit_is_blocking.emit(side, unit.coord)  # animation
			continue  # parry prevents counter attacks

		if enemy_symbol.does_pierce_defense(unit_symbol):
			# found killer
			enemy.unit_is_counter_attacking.emit(opposite_side)  # animation
			spear_holding_killer_teams.append(enemy.army_in_battle.team)
		else:
			if unit_symbol.defense_power > 1:
				unit.unit_is_blocking.emit(side, unit.coord)  # animation
			else:
				enemy.unit_is_counter_attacking.emit(opposite_side)  # temp animation fix for weak weapons

	if spear_holding_killer_teams.size() > 0:
		return true
	return false


func _process_offensive_symbols(unit : Unit, move_type : E.MoveType) -> void:
	for side in range(6):
		var unit_weapon = unit.get_symbol(side)
		if not unit_weapon.is_offensive(move_type):
			continue  # We don't have any weapon
		if unit_weapon.does_it_shoot():
			_process_bow(unit, side, unit_weapon)
			continue  # bow is special case

		var adjacent_unit := _get_adjacent_unit(unit.coord, side)
		if not adjacent_unit:
			continue # nothing to interact with
		if adjacent_unit.army_in_battle.team == unit.army_in_battle.team:
			continue # no friendly fire within team

		var enemy = adjacent_unit
		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_weapon = enemy.get_symbol(opposite_side)

		if enemy_weapon.does_parry(unit_weapon):
			# We check if parry even parries any attempt
			enemy.unit_is_blocking.emit(opposite_side, unit.coord)  # animation
			continue  # parry disables all melee symbols

		# we check if attacking symbol power is able to kill
		if unit_weapon.does_pierce_defense(enemy_weapon):
			# in case of winning battle - further attack checks won't break anything

			unit.unit_is_slashing.emit(side)  # animation
			_kill_unit(enemy, armies_in_battle_state[current_army_index])
			continue  # enemy unit died
		# in case enemy defended against attack we check if attacker pushes away enemy

		if unit_weapon.can_it_push():
			unit.unit_is_pushing.emit(side)  # animation
			_push_enemy(enemy, side, unit_weapon.push_power)
		elif unit_weapon.attack_power > 0:  # was there an attack attempt
			if enemy_weapon.defense_power > 1: # temp fix to account for missing animation for weak weapons
				enemy.unit_is_blocking.emit(opposite_side, unit.coord)  # animation
			else:
				unit.unit_is_slashing.emit(side)  # animation


## Occurs only when unit is pushed, the that unit performes attacks with passive symbols
func _process_passive_symbols(unit : Unit) -> void:
	for side in range(6):
		var unit_symbol = unit.get_symbol(side)
		if not unit_symbol.counter_attack:
			continue

		if unit_symbol.does_it_shoot():
			_process_bow(unit, side, unit_symbol)
			continue  # bow is special case

		var adjacent_unit := _get_adjacent_unit(unit.coord, side)
		if not adjacent_unit:
			continue # nothing to interact with
		if adjacent_unit.army_in_battle.team == unit.army_in_battle.team:
			continue # no friendly fire within team

		var enemy = adjacent_unit
		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_weapon = enemy.get_symbol(opposite_side)
		if enemy_weapon.does_parry(unit_symbol):
			enemy.unit_is_blocking.emit(opposite_side, unit.coord)
			continue  # parry disables all melee symbols

		# we check if attacking symbol power is able to kill
		if unit_symbol.does_pierce_defense(enemy_weapon):
			# in case of winning battle - further attack checks won't break anything
			unit.unit_is_counter_attacking.emit(side)  # animation
			_kill_unit(enemy, armies_in_battle_state[current_army_index])
			continue  # enemy unit died

		# in case enemy defended against attack we check if attacker pushes away enemy
		if unit_symbol.can_it_push():
			unit.unit_is_pushing.emit(side)  # animation
			_push_enemy(enemy, side, unit_symbol.push_power)


func _process_bow(unit : Unit, side : int, weapon : DataSymbol) -> void:
	var target := _get_shot_target(unit.coord, side, weapon.reach)

	if target == null:
		return # no target
	if target.army_in_battle.team == unit.army_in_battle.team:
		return # no friendly fire within team

	var opposite_side := GenericHexGrid.opposite_direction(side)
	var enemy_weapon : DataSymbol = target.get_symbol(opposite_side)

	if weapon.does_pierce_defense(enemy_weapon): # not blocked by shield
		unit.unit_is_shooting.emit(side, target.coord)  # animation
		_kill_unit(target, armies_in_battle_state[current_army_index])
		return  # target died

	if enemy_weapon.defense_power > 1:  # TEMP fix as system to play animation for weapons defending from weak attack doesn't exist yet
		target.unit_is_blocking.emit(opposite_side, unit.coord)  # animation
	else:
		unit.unit_is_shooting.emit(side, target.coord)  # TEMP animation of shooting without blocking

	if weapon.push_power > 0:
		_push_enemy(target, side, weapon.push_power)


## pushes enemy in non-relative direction, "power" tiles away [br]
## checks on each tile if it's possible to be moved to that spot [br]
## deppending on power value
func _push_enemy(enemy : Unit, direction : int, push_power : int) -> void:

	for pushed_distance in range(1, push_power + 1):
		var target_coord := GenericHexGrid.distant_coord(enemy.coord, direction, 1)
		var target_hex = get_hex(target_coord)

		if target_hex.pit:
			# TODO replace this "animation" of falling into pit with a custom one
			_change_unit_coord(enemy, target_coord)
			enemy.move(target_coord, _get_battle_hex(target_coord))

			_kill_unit(enemy, armies_in_battle_state[current_army_index])
			return

		if not target_hex.can_be_moved_to:
			# push behaves different for push_power equal to 1
			if push_power == 1 or pushed_distance < push_power:
				_kill_unit(enemy, armies_in_battle_state[current_army_index])
				return
			# push power innsuficient to kill a unit
			return

		var target := get_unit(target_coord)
		if target != null:
			if push_power == 1 or pushed_distance < push_power:
				_kill_unit(enemy, armies_in_battle_state[current_army_index])
				return
			return # push power innsuficient to kill a unit

		currently_processed_move_info.register_push(enemy, target_coord)

		# MOVE for PUSH (no rotate)
		_change_unit_coord(enemy, target_coord)
		enemy.move(target_coord, _get_battle_hex(target_coord))


	# check for counter_attacks
	# occurs only at last spot enemy was pushed to (push was to quick for allies to react)
	if _should_die_to_counter_attack(enemy):
		# special case when we award EXP to the player that pushed the unit instead of spear holder
		_kill_unit(enemy, armies_in_battle_state[current_army_index])
		return

	_process_passive_symbols(enemy)  # occurs only if moved unit survived the push

#endregion Symbols


#region public helpers

func get_current_player() -> Player:
	var player_index = armies_in_battle_state[current_army_index].army_reference.controller_index
	return IM.get_player_by_index(player_index)


func get_unit(coord : Vector2i) -> Unit:
	return _get_battle_hex(coord).unit


func is_move_valid(unit : Unit, coord : Vector2i) -> bool:
	return _get_move_direction_if_valid(unit, coord) != MOVE_IS_INVALID


func is_during_deployment_phase() -> bool:
	return state == STATE_DEPLOYMENT

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


func _get_adjacent_unit(coord : Vector2i, dir : int) -> Unit:
	var target_coord := GenericHexGrid.adjacent_coord(coord, dir)
	return get_unit(target_coord)


## reach - number of tiles missle can reach [br]
## reach == -1 means infinite | reach == 0 shouldn't be used
func _get_shot_target(coord : Vector2i, direction : int, reach : int = -1) -> Unit:
	assert(reach != 0, "attempt to shoot with non ranged weapon")
	var target_coord := GenericHexGrid.adjacent_coord(coord, direction)
	var hex := _get_battle_hex(target_coord)
	reach -= 1
	while not hex.unit and not hex.blocks_shots():
		if reach == 0:
			break
		target_coord = GenericHexGrid.adjacent_coord(target_coord, direction)
		hex = _get_battle_hex(target_coord)
		reach -= 1

	return hex.unit


func is_move_possible(move: MoveInfo) -> bool:
	for i in get_possible_moves():
		# Regular comparison isn't guaranteed to actually do what we want
		# Move descriptions for effectively the same moves are always the same
		if str(i) == str(move):
			return true
	return false


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


# MAJOR FUNCTION that verifies if the unit move is legal [br]
## Returns `MOVE_IS_INVALID` if move is incorrect [br]
## or a turn direction `E.GridDirections` if move is correct
func _get_move_direction_if_valid(unit : Unit, coord : Vector2i) -> int:
	"""
		For move to be valid, target coord
		- is a neighbor of the unit
		- allows movement
		- can be occupied by a new unit:
			- is empty
			- contains a unit that would be killed/pushed by the move
		- in special case that tile has a tag "special_move"
		  move is possible if the unit is facing that tile
		  that specific move may behave differently

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
		if hex.special_move and move_direction == unit.unit_rotation:
			pass # its a special move case
		else:
			return MOVE_IS_INVALID

	if hex.pit:
		# check if a landing spot is a viable move
		var jump_spot : Vector2i = GenericHexGrid.adjacent_coord(coord, move_direction)
		hex = _get_battle_hex(jump_spot)
		if not hex.can_be_moved_to:  # landing spot cannot be a special_move tile
			return MOVE_IS_INVALID

		# is unit present on landing spot
		if not hex.unit:
			return move_direction  # empty field
		else:
			if hex.unit.army_in_battle.team == unit.army_in_battle.team:
				return MOVE_IS_INVALID  # You cannot jump on top of an allied unit

			var unit_front_weapon : DataSymbol = unit.get_front_symbol()
			var opposite_side := GenericHexGrid.opposite_direction(move_direction)
			var enemy_weapon = hex.unit.get_symbol(opposite_side)
			if unit_front_weapon.is_offensive(E.MoveType.TURN) \
				and unit_front_weapon.does_it_shoot() \
				and unit_front_weapon.does_pierce_defense(enemy_weapon):
				return move_direction  # Unit got shot before jump occured
			else:
				return MOVE_IS_INVALID  # during jump unit is unable to use their weapon

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
	elif other_unit.army_in_battle.team == me.army_in_battle.team:
		return false

	var defense_direction = GenericHexGrid.opposite_direction(attack_direction)
	var enemy_symbol = other_unit.get_symbol(defense_direction)
	var front_symbol : DataSymbol = me.get_front_symbol()

	if not front_symbol.activate_turn:  # weapon doesn't activate until unit gets to the next hex
		return false
	if enemy_symbol.does_parry(front_symbol):
		return false  # parry ignores our melee symbols

	if front_symbol.can_it_push():
		return true  # push ignores enemy_unit shields

	# checks if unit attack power is sufficient
	return front_symbol.does_pierce_defense(enemy_symbol)


func _get_player_army(player : Player) -> BattleGridState.ArmyInBattleState:
	var player_index = -1
	if player:
		player_index = player.index
	for army in armies_in_battle_state:
		if army.army_reference.controller_index == player_index:
			return army
	assert(false, "No army for player " + str(player))
	return null


func _get_army_index(army : BattleGridState.ArmyInBattleState):
	var result = armies_in_battle_state.find(army)
	return result


## searches for enemy army that has a hero, with priority for the last in array [br]
## can return null [br]
## optionally it can be provided withsubset of enemy armies in case of counter attack dispute [br]
## killed_team - team_id [br]
## spear_disputer_teams - array of team id's
func _find_proper_exp_winner(killed_team : int, spear_disputer_teams : Array[int] = []) -> ArmyInBattleState:
	var priority_enemy_army : ArmyInBattleState = null
	var searched_armies_idx : Array[int] = []


	for army_idx in range(armies_in_battle_state.size()):
		var army_team = armies_in_battle_state[army_idx].team
		if army_team != killed_team:
			# If unit was killed by one or more spear holder,
			# we will only look to award exp to one of those teams
			if spear_disputer_teams.size() != 0:
				if army_team in spear_disputer_teams:
					searched_armies_idx.append(army_idx)
			else: # otherwise we search through every enemy team
				searched_armies_idx.append(army_idx)

	searched_armies_idx.reverse()

	# search for armies with present hero
	for army_idx in searched_armies_idx:
		var army_state = armies_in_battle_state[army_idx]
		if army_state.army_reference.hero == null:
			continue # we search for enemy armies that have a hero
		priority_enemy_army = army_state
		break

	return priority_enemy_army

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
		STATE_DEPLOYMENT:
			var skip_count = 0
			# skip players with nothing to deploy
			while armies_in_battle_state[current_army_index].units_to_deploy.size() == 0:
				current_army_index += 1
				current_army_index %= armies_in_battle_state.size()
				skip_count += 1
				# no player has anything to deploy, go to next phase
				if skip_count == armies_in_battle_state.size():
					state = STATE_FIGHTING
					current_army_index = 0  # first army is always present
					break

		STATE_FIGHTING:
			while not armies_in_battle_state[current_army_index].can_fight():
				current_army_index += 1
				current_army_index %= armies_in_battle_state.size()

			# new Turn starts -> all player made their moves
			if prev_idx > current_army_index:
				_end_of_turn_magic()

				# Cyclone timer update
				cyclone_target.cyclone_timer -= 1

				# end of cyclone timer = 0 | stalemate detection = -1
				assert(cyclone_target.cyclone_timer >= -1,
				"_switch_participant_turn()cyclone_target.cyclone_timer < -1" + str(cyclone_target.cyclone_timer))
				if cyclone_target.cyclone_timer in [0, -1]:
					current_army_index = _get_army_index(cyclone_target)
					state = STATE_SACRIFICE

		# Sacrifice already occured, select the first player
		# move to STATE_FIGHTING
		STATE_SACRIFICE:
			current_army_index = 0  # first army may no longer be present
			while not armies_in_battle_state[current_army_index].can_fight():
				current_army_index += 1
				current_army_index %= armies_in_battle_state.size()
			state = STATE_FIGHTING

	var next_player := armies_in_battle_state[current_army_index]
	# chess clock is updated in turn_ended() and turn_started()

	_end_of_move_magic()

	prev_player.turn_ended()

	next_player.turn_started()


## Basic Unit move:
## unit - that is going to move | direction - it will move toward
## target_title_coord - hex tile it's going to move toward (doesn't have to be adjacent)
func _perform_move(unit : Unit, direction : int, target_tile_coord : Vector2i) -> void:
	# TURN
	unit.turn(direction)
	if _process_symbols(unit, E.MoveType.TURN):
		return
	currently_processed_move_info.register_turning_complete()

	var anchored := false
	for effect in unit.effects:
		if effect.name == "Anchor":
			anchored = true

	if anchored:
		return

	# MOVE
	var target_tile : BattleGridState.BattleHex = _get_battle_hex(target_tile_coord)
	if target_tile.pit:
		# we assume move is possible
		target_tile_coord += GenericHexGrid.DIRECTION_TO_OFFSET[direction]

	_change_unit_coord(unit, target_tile_coord)
	unit.move(target_tile_coord, target_tile)
	currently_processed_move_info.register_locomote_complete()
	if _process_symbols(unit, E.MoveType.MOVE):
		return


## Spell effect:
## unit - that is going to move |
## target_title_coord - hex tile it's going to move toward (doesn't have to be adjacent)
##  direction - optional as martyr spell does not change uppon teleportation
## martyr - optional parameter that determines if teleport was used to resolve martyr spell effect
func _perform_teleport(unit : Unit, target_tile_coord : Vector2i, direction : int = -1, martyr : bool = false) -> void:
	# TURN
	if direction != -1:
		unit.turn(direction)
		# No need to chceck for counter damage here as rotation happens
		# "during" teleport so we care only about counter damage once we arrive
		currently_processed_move_info.register_turning_complete()

	# MOVE
	_change_unit_coord(unit, target_tile_coord)
	unit.move(target_tile_coord, _get_battle_hex(target_tile_coord))
	currently_processed_move_info.register_locomote_complete()
	if not martyr:
		_process_symbols(unit, E.MoveType.MOVE)


## Spell effect: [br]
## unit - that is going to move |[br]
## target_title_coord - hex tile it's going to move toward (has to be adjacent)[br]
## power - parameter used for determining how many tiles unit moves
func _perform_dash(unit : Unit, target_tile_coord : Vector2i, power : int = 3) -> void:
	# TURN
	var direction : int = GenericHexGrid.direction_to_adjacent(unit.coord, target_tile_coord)
	assert(direction != GenericHexGrid.TILES_NOT_ADJACENT, "_perform_dash: Target tile was not adjascent")
	unit.turn(direction)
	# No need to chceck for counter damage here as rotation happens
	# "during" teleport so we care only about counter damage once we arrive
	currently_processed_move_info.register_turning_complete()

	# MOVE
	for dashed_distance in range(power):
		if not _is_movable(target_tile_coord) or get_unit(target_tile_coord):
			_kill_unit(unit)
			return
		_change_unit_coord(unit, target_tile_coord)
		unit.move(target_tile_coord, _get_battle_hex(target_tile_coord))
		target_tile_coord = GenericHexGrid.adjacent_coord(target_tile_coord, direction)
		#currently_processed_move_info.register_locomote_complete() #TODO verify if needed
		_process_offensive_symbols(unit, E.MoveType.MOVE)

	if _should_die_to_counter_attack(unit):
		_kill_unit(unit)


func _summon_a_unit(caster : Unit, summoned_unit : DataUnit, target_tile_coord : Vector2i) -> void:
	summoned_unit.summoned = true
	var direction : int = GenericHexGrid.direction_to_adjacent(caster.coord, target_tile_coord)
	var unit : Unit = caster.army_in_battle.deploy_unit(summoned_unit, target_tile_coord, direction)

	# Apply summon sickness
	var success : bool = unit.try_adding_magic_effect(load(CFG.SUMMONING_SICKNESS_PATH))
	assert(success, "failure to apply summoning sickness effect")

	_put_unit_on_grid(unit, target_tile_coord)


## changes coordinates of the unit ONLY (doesn't activate attack or anything like that)
func _change_unit_coord(unit : Unit, target_coord : Vector2i) -> void:
	_remove_unit(unit)
	_put_unit_on_grid(unit, target_coord)

	var target_tile : BattleGridState.BattleHex = _get_battle_hex(target_coord)
	if target_tile.is_mana_tile():
		unit.unit_captured_mana.emit(target_coord)
		capture_mana_well(target_tile, unit.army_in_battle)


## Used for movement, kills, undeploy(undo) [br]
## removes Unit from logic hex tile
func _remove_unit(unit : Unit) -> void:
	var hex := _get_battle_hex(unit.coord)
	assert(hex.unit == unit, "incorrect remove unit, coord desync")
	hex.unit = null


## Main kill unit function -> checks for end of battle
## Contains spells related logic
func _kill_unit(target : Unit, killer_army : ArmyInBattleState = null) -> void:
	var target_army_index := _find_army_idx(target.controller)
	var target_army = _get_player_army(target.controller)

	# check magic to confirm if it dies
	var replaced_target : Unit = null
	var new_target_pos : Vector2i

	# reversed for loop to avoid problems with removing spells mid search
	for spell_idx in range(target.effects.size() - 1, -1, -1):
		#spell.enchanted_unit_dies()
		var spell = target.effects[spell_idx]
		match spell.name:
			"Martyr":
				target.effects.erase(spell)
				target.effect_state_changed()  # Visuals

				for unit in target_army.units:
					if replaced_target:
						break
					for ally_spell in unit.effects:
						if ally_spell.name == "Martyr":
							replaced_target = target
							target = unit
							new_target_pos = unit.coord
							break
			"Second Wind":
				target.effects.erase(spell)
				target.effect_state_changed()  # Visuals

				#TODO consider getting info of the killer position to make it a knockback from them instead of just a push to the back

				_push_enemy(target, GenericHexGrid.opposite_direction(target.unit_rotation), 3)

				#_perform_teleport(replaced_target, new_target_pos, -1, true)
				return

	currently_processed_move_info.register_kill(target_army_index, target)


	# killing starts - award exp
	if spear_holding_killer_teams.size() > 0:
		killer_army = _find_proper_exp_winner(target_army.team, spear_holding_killer_teams)
		spear_holding_killer_teams = []

	if killer_army:
		killer_army.killed_units.append(target.template.level)

		#TODO move this elsewhere so that durability gets lowered by 1 each killing turn regardless of number of killed units
		for effect in currently_active_unit.effects:
			if effect.name == "Magic Weapon":
				effect.magic_weapon_durability -= 1
				if effect.magic_weapon_durability < 1:
					effect.magic_weapon_durability = 1

				for symbol in currently_active_unit.symbols:
					if symbol.attack_power != 0:
						symbol.attack_power = effect.magic_weapon_durability

	# removal of unit
	target_army.kill_unit(target)
	_remove_unit(target) # remove reference from hextile
	target.unit_killed() # emit singal for visual death animation

	# verify battle has ended before any additonal spell effects take place
	_check_battle_end()
	if not battle_is_ongoing():
		return

	if replaced_target: # "Martyr" spell quick hack
		_perform_teleport(replaced_target, new_target_pos, -1, true) # martyr teleport temp fix


	# trigger any post death spell effect
	for spell in target.effects:
		#TEMP passing "currently_active_unit" here works only for vengeance
		spell.apply_effect(currently_active_unit, "post death spell effect")

	mana_values_changed() # TEMP occurs every time after death

	var units_on_board : Dictionary = {}

	for army in armies_in_battle_state:
		for unit in army.units:
			units_on_board[unit.template.unit_name] = unit

	if units_on_board.size() == 2 and units_on_board.has("elf_3") \
	and units_on_board.has("orc_2"):
		stalemate_failsafe_on = true
		stalemate_failsafe_start = turn_counter


## Rare event when all players repeated their moves -> it pushes cyclone timer to activate next turn
func end_stalemate() -> void:
	print_rich("[color=pink]END OF STALEMATE")
	# it has to be 0 in case if value where to be
	# 1 leads to bugs

	#TODO fix stalemate ending action
	# Temporarly disabled duo to issues with independent refactors that made ths feature broken
	#cyclone_target.cyclone_timer = 0

#endregion Gameplay Events


#region Deployment Phase

func current_player_can_deploy_on(coord : Vector2i) -> bool:
	return _can_deploy_on(current_army_index, coord)


func _can_deploy_on(army_idx : int, coord : Vector2i) -> bool:
	var hex := _get_battle_hex(coord)
	return  hex.spawn_point_army_idx == army_idx and hex.unit == null


func _get_deploy_rotation(coord : Vector2i) -> int:
	return _get_battle_hex(coord).spawn_direction


func _put_unit_on_grid(unit : Unit, coord : Vector2i) -> void:
	var hex := _get_battle_hex(coord)
	# TODO discuss this assert as it conflicts with special move tiles
	#assert(hex.can_be_moved_to, "deployed unit to an invalid tile")
	assert(not hex.unit, "deploying unit to an occupied tile")
	hex.unit = unit

#endregion Deployment Phase


#region Timer

## in miliseconds -- called only by BM _check_clock_timer_tick()
func get_current_time_left() -> int:
	return armies_in_battle_state[current_army_index].get_time_left_ms()


## only for Replays
func set_displayed_time_left_ms(time_left_ms : int) -> void:
	armies_in_battle_state[current_army_index].set_time_left_ms(time_left_ms)

## only for replays
func set_clock_enabled(enabled: bool):
	for army in armies_in_battle_state:
		army.clock_enabled = enabled

#endregion Timer


#region Mana Cyclone Timer

## Occurs any time a unit is killed [br]
## It may change the cyclone_target
func mana_values_changed() -> void:
	# TODO this function needs to account for teams rather than individual armies

	# we search for army with lowest amount of mana points
	var current_worst = armies_in_battle_state[0]
	# we also search for an army with the biggest amount of points,
	var current_best = armies_in_battle_state[-1]

	# player later in an array win on ties between mana values - it's intentional
	for army in armies_in_battle_state:
		if current_worst.mana_points > army.mana_points:
			current_worst = army
		if current_best.mana_points < army.mana_points:
			current_best = army

	cyclone_target = current_worst

	var mana_difference = current_best.mana_points - current_worst.mana_points
	## TODO consider moving it to a sepereta balance file instead of CFG
	var new_cylone_counter = 0
	if mana_difference >= 11:
		new_cylone_counter = 5
	elif mana_difference >= 8:
		new_cylone_counter = 10
	elif mana_difference >= 4:
		new_cylone_counter = 15
	elif mana_difference >= 2:
		new_cylone_counter = 20
	elif mana_difference == 1:
		new_cylone_counter = CFG.BIG_CYCLONE_COUNTER_VALUE
	else: # mana_difference == 0
		new_cylone_counter = CFG.BIG_CYCLONE_COUNTER_VALUE


	if mana_difference > CFG.CYCLONE_MANA_THRESHOLD:
		new_cylone_counter = CFG.SMALL_CYCLONE_COUNTER_VALUE


	if current_worst.cyclone_timer == 0:  # Cyclone just killed a unit, so now it resets
		current_worst.cyclone_timer = new_cylone_counter

	elif current_worst.cyclone_timer > new_cylone_counter:  # cyclone target timer simply got lower
		current_worst.cyclone_timer = new_cylone_counter


func cyclone_get_current_target() -> Player:
	return IM.get_player_by_index( \
		cyclone_target.army_reference.controller_index)


func cyclone_get_current_target_turns_left() -> int:
	return cyclone_target.cyclone_timer


func capture_mana_well(hex : BattleHex, army : ArmyInBattleState):
	if hex.mana_controller:
		hex.mana_controller.mana_points -= MANA_WELL_POWER
	hex.mana_controller = army
	army.mana_points += MANA_WELL_POWER
	mana_values_changed()

#endregion Mana Cyclone Timer


#region Magic

## verifies if spell can be casted
func is_spell_target_valid(caster : Unit, coord : Vector2i, spell : BattleSpell) -> bool:
	match spell.name:
		"Vengeance": # any current player controlled unit
			var target = get_unit(coord)
			if target and target.controller == caster.controller:
				return true
		"Martyr": # any current player controlled unit, but not the caster
			var target = get_unit(coord)
			if target and target.controller == caster.controller and target != caster:
				return true
		"Fireball": # any hex target is valid
			return true
		"Anchor": # any unit
			var target = get_unit(coord)
			if target:
				return true
		"Teleport", "Wind Dash": # tile in range that is in front of the caster
			if get_unit(coord) or not _get_battle_hex(coord).can_be_moved_to:  # tile has to be empty
				return false
			var spell_range : int = 1
			match spell.name:
				"Teleport":
					spell_range = 3
				"Wind Dash":
					spell_range = 1
				_:
					printerr("Unsupported spell range value")

			if _is_faced_tile_in_range(caster.coord, coord, caster.unit_rotation, spell_range):
				return true
		"Summon Dryad":  # adjacent empty tile to caster
			if get_unit(coord) or not _get_battle_hex(coord).can_be_moved_to:
				return false
			return is_adjacent(caster.coord, coord)
		"Blood Ritual":  # any enemy units -> when enemy has more than 1 unit
			var target = get_unit(coord)
			if target and target.controller.team != caster.controller.team and \
				target.army_in_battle.units.size() >= 2:
				return true
		_:
			printerr("Spell targeting not supported: ", spell.name)
			return false

	return false #TEMP


## spell takes an effect
func _perform_magic(unit : Unit, target_tile_coord : Vector2i, spell : BattleSpell) -> void:

	match spell.name:
		"Vengeance", "Blood Ritual", "Anchor":
			spell.cast_effect(get_unit(target_tile_coord), "casting")
			#print(get_unit(target_tile_coord).effects)

		"Martyr":
			# target as well as caster both get affected
			spell.cast_effect(unit, "casting")
			spell.cast_effect(get_unit(target_tile_coord), "casting")
			#print(get_unit(target_tile_coord).effects)

		"Fireball":
			var enemy_targets : Array[Unit] = []
			var ally_targets : Array[Unit] = []
			var target : Unit = get_unit(target_tile_coord)
			if target and target.army_in_battle.team == unit.army_in_battle.team:
				ally_targets.append(target)
			elif target:
				enemy_targets.append(target)
			for direction in DIRECTION_TO_OFFSET:
				target = get_unit(target_tile_coord + direction)
				if target and target.army_in_battle.team == unit.army_in_battle.team:
					ally_targets.append(target)
				elif target:
					enemy_targets.append(target)

			for enemy_unit in enemy_targets: # kill enemy units first
				_kill_unit(enemy_unit, armies_in_battle_state[current_army_index])

			# we only start killing ally units after we are sure battle didn't end yet
			if not battle_is_ongoing():
				return

			var priority_enemy_army : ArmyInBattleState = _find_proper_exp_winner(unit.army_in_battle.team)

			for ally_unit in ally_targets: # kill rest
				_kill_unit(ally_unit, priority_enemy_army)

		"Teleport":
			_perform_teleport(unit, target_tile_coord)

		"Wind Dash":
			_perform_dash(unit, target_tile_coord)

		"Summon Dryad":
			_summon_a_unit(unit, spell.summon_unit_data, target_tile_coord)

		_:
			printerr("Spell perform not supported: ", spell.name)
			return

	unit.spells.erase(spell) # Remove to test casting multiple times


## spell effects that occur after allmove related event already took place [br]
## runs for all units
func _end_of_move_magic() -> void:
	for army in armies_in_battle_state:
		if not battle_is_ongoing(): #TODO verify if thats a proper fix for spell combination, which results in a draw
			return
		for unit : Unit in army.units:
			for magic_effect in unit.effects:
				match magic_effect.name:
					"Blood Ritual":
						if army.units.size() == 1:
							_kill_unit(unit)
					"Death Mark":
						_kill_unit(unit)
						break


## STUB for proper countdown system
## spell effects that occur only after all players made their moves [br]
## runs for all units
func _end_of_turn_magic() -> void:
	for army in armies_in_battle_state:
		for unit : Unit in army.units:
			for effect_idx in range(unit.effects.size() -1, -1, -1):
				var magic_effect : BattleMagicEffect = unit.effects[effect_idx]

				if not magic_effect.passive_effect:  # Duration
					magic_effect.duration_counter -= 1
					if magic_effect.duration_counter == 0:
						unit.effects.pop_at(effect_idx)
						if magic_effect.name == "Summoning Sickness":
							unit.try_adding_magic_effect(magic_effect.spell_effects[0])
						continue

				match magic_effect:
					_:
						pass
				unit.effect_state_changed()

#endregion Magic


#region End Battle

func _kill_army(army_idx : int):
	currently_processed_move_info = MoveInfo.make_surrender()
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
			if army.team not in teams_alive:
				teams_alive.append(army.team)

	if teams_alive.size() < 2:
		state = STATE_BATTLE_FINISHED
		return


func force_win_battle():
	var controller_player_armies : Array[int] = []
	var teams_not_controlled_by_cheating_player : Array[int] = []

	# Collect infomration about armies to target
	for army_idx : int in range(armies_in_battle_state.size()):
		var army : ArmyInBattleState = armies_in_battle_state[army_idx]
		if IM.players[army.army_reference.controller_index].is_local():  # TODO apply controllers to army in custom battles
			controller_player_armies.append(army_idx)
		else:
			teams_not_controlled_by_cheating_player.append(army.team)

	# unique case where player cheating controlls some part fo every side of the conflict
	if teams_not_controlled_by_cheating_player.size() == 0:
		# kill every army expect the current one
		for army_idx in range(armies_in_battle_state.size()):
			if army_idx == current_army_index:
				continue
			_kill_army(army_idx)
			return

	# kill all armies that player is not a team member of
	for army_idx in range(armies_in_battle_state.size()):
		var army : ArmyInBattleState = armies_in_battle_state[army_idx]
		if army.team in teams_not_controlled_by_cheating_player:
			_kill_army(army_idx)


func surrender_on_timeout():
	_kill_army(current_army_index)


func force_surrender():
	var controller_player_army_to_surrender : Array[int] = []
	var teams_not_controlled_by_surrendering_player : Array[int] = []
	for army_idx : int in range(armies_in_battle_state.size()):
		var army : ArmyInBattleState = armies_in_battle_state[army_idx]
		if IM.players[army.army_reference.controller_index].is_local():  # TODO apply controllers to army in custom battles
			controller_player_army_to_surrender.append(army_idx)
		else:
			teams_not_controlled_by_surrendering_player.append(army.team)
	if teams_not_controlled_by_surrendering_player.size() == 0:
		_kill_army(current_army_index)
		return

	for army_idx in controller_player_army_to_surrender:
		_kill_army(army_idx)


#endregion End Battle


#region AI Helpers

func get_possible_moves() -> Array[MoveInfo]:
	if is_during_deployment_phase():
		return _get_all_deploy_moves()
	if state == STATE_SACRIFICE:
		return _get_all_sacrifice_moves()

	return _get_all_unit_moves()


func _get_deployment_tiles(player : Player) -> Array[Vector2i]:
	var army_idx = _find_army_idx(player)
	var result : Array[Vector2i] = []
	for x in range(width):
		for y in range(height):
			var coord := Vector2i(x,y)
			if _can_deploy_on(army_idx, coord):
				result.append(coord)
	return result


func _get_not_deployed_units(player : Player) -> Array[DataUnit]:
	var index = player.index if player else -1
	for a in armies_in_battle_state:
		if a.army_reference.controller_index == index:
			return a.units_to_deploy.duplicate()
	assert(false, "ai asked for units to deploy but it doesn't control any army")
	return []


func _get_units(player : Player) -> Array[Unit]:
	var idx = _find_army_idx(player)
	return armies_in_battle_state[idx].units


func _find_army_idx(player : Player) -> int:
	# change done in merge -- neutral player is null and we then need -1 index
	# also, should be moved to some function
	var player_index = -1
	if player:
		player_index = player.index
	for idx in range(armies_in_battle_state.size()):
		if armies_in_battle_state[idx].army_reference.controller_index == player_index:
			return idx
	assert(false, "ai asked for army idx for player who doesnt control any army")
	return -1


## get's all move action not deploy/magic/sacrifice ones
func _get_all_unit_moves() -> Array[MoveInfo]:
	var legal_moves : Array[MoveInfo] = []
	var my_units := _get_units(get_current_player())

	for unit in my_units:
		for side in range(6):
			var new_coord = GenericHexGrid.adjacent_coord(unit.coord, side)
			var move_dir = _get_move_direction_if_valid(unit, new_coord)
			if move_dir != BattleGridState.MOVE_IS_INVALID:
				legal_moves.append(MoveInfo.make_move(unit.coord, new_coord))
		for spell in unit.spells:
			legal_moves.append_array(_get_magic_moves(unit, spell))
	return legal_moves

func _get_magic_moves(unit: Unit, spell: BattleSpell) -> Array[MoveInfo]:
	# TODO lazy but very inefficient method, perhaps needs a rewrite?
	var result : Array[MoveInfo] = []
	for x in width:
		for y in height:
			if is_spell_target_valid(unit, Vector2i(x,y), spell):
				result.push_back(MoveInfo.make_magic(unit.coord, Vector2i(x,y), spell))
	return result

func _get_all_sacrifice_moves() -> Array[MoveInfo]:
	var legal_moves : Array[MoveInfo] = []
	var my_units := _get_units(get_current_player())

	for unit in my_units:
		legal_moves.append(MoveInfo.make_sacrifice(unit.coord))
	return legal_moves


func _get_all_deploy_moves() -> Array[MoveInfo]:
	var legal_moves: Array[MoveInfo] = []
	var me = get_current_player()
	var spawn_tiles = _get_deployment_tiles(me)
	var units = _get_not_deployed_units(me)
	for unit in units:
		for spawn_tile in spawn_tiles:
			legal_moves.append(MoveInfo.make_deploy(unit, spawn_tile))

	return legal_moves


## only legal moves are supported
func filter_only_kill_moves(all_moves : Array[MoveInfo]) -> Array[MoveInfo]:
	var all_kill_moves : Array[MoveInfo] = []
	for move in all_moves:
		if _is_kill_move(move):
			all_kill_moves.append(move)

	return all_kill_moves


func _get_melee_attack_kills(unit : Unit, direction : int, coord : Vector2i, move_type : E.MoveType) -> Array[Unit]:
	var adjacent_units : Array[Unit] = _get_adjacent_units(coord)
	var killed_enemy_units : Array[Unit] = []

	for side in range(6):
		var unit_weapon = unit.get_symbol_when_rotated(direction, side)
		if not unit_weapon.is_offensive(move_type):
			continue  # We don't have any weapon
		if unit_weapon.does_it_shoot():
			continue  # we don't verify ranged weapons here
		if not adjacent_units[side]:
			continue  # nothing to interact with
		if adjacent_units[side].army_in_battle.team == unit.army_in_battle.team:
			continue  # no friendly fire within team

		var enemy : Unit = adjacent_units[side]
		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_weapon : DataSymbol = enemy.get_symbol(opposite_side)
		if enemy_weapon.does_parry(unit_weapon):
			continue  # parry disables all melee symbols

		# we check if attacking symbol power is able to kill
		if unit_weapon.does_pierce_defense(enemy_weapon):
			killed_enemy_units.append(enemy)
			continue
		# in case enemy defended against attack we check if attacker pushes away enemy
		if unit_weapon.can_it_push():
			if _will_push_kill(enemy, side, unit_weapon.push_power):
				killed_enemy_units.append(enemy)
				continue

	return killed_enemy_units


func _will_push_kill(pushed_unit : Unit, direction : int, push_power : int) -> bool:
	var target_coord := pushed_unit.coord

	for pushed_distance in range(1, push_power + 1):
		target_coord = GenericHexGrid.distant_coord(target_coord, direction, 1)
		var target_hex = get_hex(target_coord)

		if target_hex.pit:
			return true

		if not target_hex.can_be_moved_to:
			# push behaves different for power equal to 1
			if push_power == 1 or pushed_distance < push_power:
				return true
			# push power innsuficient to kill a unit
			return false

		var target := get_unit(target_coord)
		if target != null:
			# push behaves different for power equal to 1
			if push_power == 1 or pushed_distance < push_power:
				return true
			else:
				return false

		var spear_killers = _get_counter_attack_killers(pushed_unit, pushed_unit.unit_rotation, target_coord)
		if spear_killers.size() > 0:
			return true
	return false


func _get_counter_attack_killers(unit : Unit, direction : int, coord : Vector2i) -> Array[Unit]:
	# Returns all units that will kill this unit it were present on this tile
	var killer_units : Array[Unit] = []

	var adjacent_units = _get_adjacent_units(coord)

	for side in range(6):
		var enemy_unit = adjacent_units[side]
		if not enemy_unit:
			continue  # no unit
		if enemy_unit.army_in_battle.team == unit.army_in_battle.team:
			continue  # no friendly fire within team

		var unit_symbol : DataSymbol = unit.get_symbol_when_rotated(side, direction)
		if get_hex(coord).swamp:
			unit_symbol = CFG.EMPTY_SYMBOL

		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_symbol : DataSymbol = enemy_unit.get_symbol(opposite_side)

		if unit_symbol.does_parry(enemy_symbol):
			continue  # parry prevents counter attacks

		if enemy_symbol.counter_attack:
			if enemy_symbol.does_pierce_defense(unit_symbol):
				killer_units.append(enemy_unit)

	return killer_units


## Returns unit references of targets that this unit would have pushed it if were to move in given direction [br]
## coord argument is optional as it is useful only during teleportation magic prediction
func _get_pushed_away_targets(unit : Unit, direction : int, move_type : E.MoveType, coord : Vector2i = Vector2i.ZERO) -> Array[Unit]:
	var pushed_away_units : Array[Unit] = []
	if coord == Vector2i.ZERO:
		coord = unit.coord

	var adjacent_units : Array[Unit] = _get_adjacent_units(coord)
	for side in range(6):
		var unit_weapon : DataSymbol = unit.get_symbol_when_rotated(direction, side)
		if not unit_weapon.is_offensive(move_type):
			continue  # We don't have any weapon
		if unit_weapon.does_it_shoot():
			continue  # we don't verify ranged weapons here
		if not adjacent_units[side]:
			continue  # nothing to interact with
		if adjacent_units[side].army_in_battle.team == unit.army_in_battle.team:
			continue  # no friendly fire within team

		var enemy : Unit = adjacent_units[side]
		var opposite_side := GenericHexGrid.opposite_direction(side)
		var enemy_weapon : DataSymbol = enemy.get_symbol(opposite_side)
		if enemy_weapon.does_parry(unit_weapon):
			continue  # parry disables all melee symbols

		# we check if attacking symbol power is able to kill
		if unit_weapon.does_pierce_defense(enemy_weapon):
			#killed_enemy_units.append(enemy)
			continue
		# in case enemy defended against attack we check if attacker pushes away enemy
		if unit_weapon.can_it_push():
			pushed_away_units.append(enemy)
			#TODO consider if removing killed units from result array would be beneficial
			#if _will_push_kill(enemy, side, unit_weapon.push_power()):
			#	killed_enemy_units.append(enemy)
			#	continue

	return pushed_away_units


## returns true if that move will lead to enemy death [br]
## doesn't account that in may after killing someone die instantly
func _is_kill_move(move : MoveInfo) -> bool:
	var consequences = get_move_consequences(move)
	return consequences == MoveConsequences.KILL or consequences == MoveConsequences.KAMIKAZE


## assumes move is legal
func get_move_consequences(move : MoveInfo) -> MoveConsequences:
	# list of checks:
	# 1 verify if turning in (starting move with that unit) will even work
	# 2 turning in that direction would shoot someone
	# 3 turing in that direction will kill someone
	# 4 you can survive entering that tile
	# 5 you can kill someone entering that tile
	# 6 you can shoot someone after entering that tile

	var kill_registered = false

	if move.move_type != MoveInfo.TYPE_MOVE:  # TODO add support for spells and sacrifices
		return MoveConsequences.NONE # deployment doesn't kill

	var attacker = get_unit(move.move_source)
	var move_direction : int = GenericHexGrid.direction_to_adjacent( \
			move.move_source, move.target_tile_coord);

	# step 1
	if _get_counter_attack_killers(attacker, move_direction, move.move_source).size() > 0:
		return MoveConsequences.DEATH  # will die to a spear befor it can kill

	# step 2 BOW
	for side in range(6):  # we check each side for a ranged attack symbol
		var symbol : DataSymbol = attacker.get_symbol_when_rotated(side, move_direction)

		if not symbol.does_it_shoot():
			continue
		if not symbol.activate_turn:
			continue

		var target : Unit = _get_shot_target(move.move_source, side, symbol.reach)
		if target and target.army_in_battle.team != attacker.army_in_battle.team:
			var opposite_side = GenericHexGrid.opposite_direction(side)
			var target_symbol : DataSymbol = target.get_symbol(opposite_side)

			if symbol.does_pierce_defense(target_symbol):
				kill_registered = true  # can shoot enemy in this direction
			if symbol.push_power > 0 and _will_push_kill(target, side, symbol.push_power):
				kill_registered = true  # shot enemy was pushed to his death


	# step 3 melee weapon on first rotation
	var melee_killed_enemy_units = _get_melee_attack_kills(attacker, move_direction, move.move_source, E.MoveType.TURN)
	if melee_killed_enemy_units.size() > 0:
		kill_registered = true

	# step 4
	var counter_attack_killers = _get_counter_attack_killers(attacker, move_direction, move.target_tile_coord)

	# Check for rare specific case when archer walks into a single enemy spear killing it during rotation
	if counter_attack_killers.size() == 1:  # there is only a single spear pointing
		var front_symbol : DataSymbol = attacker.get_front_symbol()
		var enemy_unit = _get_adjacent_unit(move.target_tile_coord, move_direction)
		if enemy_unit:
			var enemy_symbol : DataSymbol = enemy_unit.get_symbol(GenericHexGrid.opposite_direction(move_direction))

			if enemy_unit == counter_attack_killers[0] \
				and front_symbol.does_it_shoot() \
				and front_symbol.activate_turn \
				and front_symbol.does_pierce_defense(enemy_symbol):
				# unit we would kill with our arrow is that killer
					return MoveConsequences.KILL

	# check for rare specific case when spear holder was killed during first rotation using melee
	for killed in melee_killed_enemy_units:
		if killed in counter_attack_killers:
			counter_attack_killers.erase(killed)

	# check for rare specific case when spear holder was pushed away during first rotation using melee
	var pushed_away_units = _get_pushed_away_targets(attacker, move_direction, E.MoveType.TURN)

	for pushed_target in pushed_away_units:
		if pushed_target in counter_attack_killers:
			counter_attack_killers.erase(pushed_target)

	if counter_attack_killers.size() > 0: # will die to a spear before it can kill
		return MoveConsequences.KAMIKAZE if kill_registered else MoveConsequences.DEATH

	# step 5
	# check for rare case when unit has a push weapon in front and it would push enemy unit away while entering that tile
	var pushed_enemy_unit = get_unit(move.target_tile_coord)
	if pushed_enemy_unit and not kill_registered:  # no need to check if unit in front was already killed
		# if kill hasn't occured yet and unit is able to enter tile with enemy it means it ahs push power in front
		var push_power : int = attacker.get_front_symbol().push_power + 1  # +1 accounts for unit still being on her old spot
		if _will_push_kill(pushed_enemy_unit, move_direction, push_power):
			return MoveConsequences.KILL

	## ----- MOVE OCCURS ------
	var target_tile_coord : Vector2i = move.target_tile_coord
	var target_hex : BattleHex = get_hex(target_tile_coord)
	if target_hex.pit:  # we perform jump
		target_tile_coord += GenericHexGrid.DIRECTION_TO_OFFSET[move_direction]
		target_hex = get_hex(target_tile_coord)

	if not target_hex.swamp:
		melee_killed_enemy_units = _get_melee_attack_kills(attacker, move_direction, move.target_tile_coord, E.MoveType.MOVE)
	else:
		melee_killed_enemy_units = []
	if melee_killed_enemy_units.size() > 0:
		kill_registered = true

	# step 6
	for side in range(6):  # we check each side for a ranged attack symbol
		var symbol : DataSymbol = attacker.get_symbol_when_rotated(side, move_direction)
		if get_hex(target_tile_coord).swamp:
			break

		if not symbol.does_it_shoot():
			continue
		if not symbol.activate_move:
			continue

		var target : Unit = _get_shot_target(target_tile_coord, side, symbol.reach)
		if target and target.army_in_battle.team != attacker.army_in_battle.team:
			var opposite_side = GenericHexGrid.opposite_direction(side)
			var target_symbol : DataSymbol = target.get_symbol(opposite_side)

			if symbol.does_pierce_defense(target_symbol):
				kill_registered = true  # can shoot enemy in this direction
			if symbol.push_power > 0 and _will_push_kill(target, side, symbol.push_power):
				kill_registered = true  # shot enemy was pushed to his death

	return MoveConsequences.KILL if kill_registered else MoveConsequences.NONE

#endregion AI Helpers



#region Subclasses

class BattleHex:
	var unit : Unit
	var spawn_point_army_idx : int = -1
	var spawn_direction : int
	var can_be_moved_to : bool = true
	var can_shoot_through : bool = true

	# Tile types (some tiles in the future may have )
	var swamp : bool = false
	var mana : bool = false
	var pit : bool = false
	var hill : bool = false

	## allows unit to "enter" the tile under the condition
	## that it's facing it
	var special_move : bool = false

	var mana_controller : ArmyInBattleState

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
		if data.type == "SENTINEL":
			return null

		var result = BattleHex.new()

		if data.type.substr(1) == "_player_spawn":
			result.spawn_point_army_idx = data.type[0].to_int() - 1
			result.spawn_direction = get_spawn_direction(result.spawn_point_army_idx)
			return result


		match data.type:
			"hole":
				result.can_be_moved_to = false
				result.pit = true
				result.special_move = true
			"wall":
				result.can_be_moved_to = false
				result.can_shoot_through = false
				result.special_move = true
				result.hill = true
			"swamp":
				result.swamp = true
			"EMPTY":
				pass
			"mana_well":
				result.mana = true
			_:
				assert(false, "'%s' tile type is not supported" % [data.type])

		return result


	func blocks_shots() -> bool:
		return not can_shoot_through


	func is_mana_tile() -> bool:
		return mana


class ArmyInBattleState:
	## used only for undo and cheats
	var battle_grid_state : WeakRef # BattleGridState

	var army_reference : Army

	## basic idx reference to which units are allies
	var team : int = -1

	var units_to_deploy : Array[DataUnit] = []
	## alive already deployed units
	var units : Array[Unit] = []
	## owned units that died during combat
	var dead_units : Array[DataUnit] = []

	#STUB - the only relevant information about killed units is their level
	var killed_units : Array[int]

	var mana_points : int = 0  # TEMP CHANGE to 0 for tournament
	var cyclone_timer : int = 100

	var hero : Hero:
		get:
			return army_reference.hero
		set(_no_value):
			assert(false, "don't change the hero here")

	## may be disabled by a replay
	var clock_enabled := true
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
		if army.hero and not army.hero.wounded: #TEMP
			var hero_unit : DataUnit = army.hero.template.data_unit
			result.units_to_deploy.append(hero_unit)

		# unit list
		for unit : DataUnit in army.units_data:
			result.units_to_deploy.append(unit)

			result.mana_points += unit.mana # MANA

		result.apply_passive_effects(state)

		#Temp solution for world map, where proper clock system isn't implemented yet
		if army.timer_reserve_sec == 0:
			army.timer_reserve_sec = 3000
		#TEMP
		result.start_turn_clock_time_left_ms = army.timer_reserve_sec * 1000
		result.turn_increment_ms = army.timer_increment_sec * 1000
		result.turn_started() # TEMP - FIXME - better init for chess clock

		return result

	func apply_passive_effects(state : BattleGridState) -> void:
		if not hero:
			return
		for effect in hero.passive_effects:
			match effect.passive_name:
				"ballista_summon":
					# HACK -> there are no armies in that array, if this army is the first one being created
					if state.armies_in_battle_state.size() != 0:
						continue  # only attacker can use ballista
					var ballista : DataUnit = load(CFG.BALLISTA_PATH)
					ballista.summoned = true
					units_to_deploy.append(ballista)


	func turn_started() -> void:
		turn_start_timestamp = Time.get_ticks_msec()


	func get_time_left_ms() -> int:
		var turn_time_local_passed_ms = Time.get_ticks_msec() - turn_start_timestamp
		if not clock_enabled:
			return start_turn_clock_time_left_ms # Time shouldn't pass in replays
		return start_turn_clock_time_left_ms - turn_time_local_passed_ms


	func set_time_left_ms(time_left_ms : int) -> void:
		turn_start_timestamp = Time.get_ticks_msec()
		start_turn_clock_time_left_ms = time_left_ms


	func turn_ended() -> void:
		# clock disabled in replays, otherwise this messes with timer - adds a large time value to timer
		if clock_enabled:
			start_turn_clock_time_left_ms = get_time_left_ms()
			start_turn_clock_time_left_ms += turn_increment_ms

	## Manages unit relation to it's related army object [br]
	## Used in so that "summary"
	func kill_unit(target : Unit) -> void:
		print("killing ", target.coord, " ",target.template.unit_name)
		assert(target in units)
		if target.template.mana > 0:
			mana_points -= target.template.mana
			# mana_value changed gets called after every kill anyway

		units.erase(target)

		dead_units.append(target.template)
		if not can_fight():  # remove all summons once are alive units have died
			kill_army()
		#gdlint: ignore=private-method-call


	func revive(kill_info : MoveInfo.KilledUnit) -> Unit:
		var unit = kill_info.respawn()
		unit.controller = IM.get_player_by_index(army_reference.controller_index)
		unit.army_in_battle = self

		dead_units.erase(unit.template)
		units.append(unit)
		return unit


	func kill_army() -> void:
		dead_units.append_array(units_to_deploy)
		units_to_deploy.clear()
		for unit_idx in range(units.size() - 1, -1, -1):
			battle_grid_state.get_ref()._kill_unit(units[unit_idx])


	func can_fight() -> bool:
		var alive_not_summoned_units : int = 0
		for unit in units:
			if not unit.summoned:
				alive_not_summoned_units += 1
		return alive_not_summoned_units > 0 or units_to_deploy.size() > 0


	func deploy_unit(unit_data : DataUnit, coord : Vector2i, rotation : int) -> Unit:
		units_to_deploy.erase(unit_data)
		var player = IM.get_player_by_index(army_reference.controller_index)
		var result = Unit.create(player, unit_data, coord, rotation, self)
		units.append(result)

		if not army_reference.hero or army_reference.hero.template.data_unit != unit_data:
			return result  # it's not a hero

		## Applying hero passive effects
		for passive_effect in army_reference.hero.passive_effects:
			if not passive_effect:  # TEMP null check until all pasives in level_up_screen are present
				continue
			match passive_effect.passive_name:
				"magic_weapons":
					var effect : BattleMagicEffect = load(CFG.hero_magic_weapon_effect)
					var success : bool = result.try_adding_magic_effect(effect)
					assert(success, "couldn't add passive effect to a hero unit upon it's deployment")
					for symbol in result.symbols:
						if symbol.attack_power != 0:
							symbol.attack_power = effect.magic_weapon_durability
				"weak_weapons":
					var weak_weapon : DataSymbol = load(CFG.weak_weapon)
					for side in range(6):
						var symbol = result.symbols[side]

						if symbol.symbol_name == "empty": # TODO verify and note the choice in the documentation, if thats a proper way to verify symbol is empty
							result.symbols[side] = weak_weapon.duplicate()
				"wind_weapons":
					for symbol in result.symbols:
						if symbol.attack_power != 0:
							symbol.push_power += 1
				"second_wind":
					var effect : BattleMagicEffect = load(CFG.hero_second_wind_effect)
					var success : bool = result.try_adding_magic_effect(effect)
					assert(success, "couldn't add passive effect to a hero unit upon it's placement")

		return result


	func undeploy(coord : Vector2i):
		var target = battle_grid_state.get_ref().get_unit(coord)
		units.erase(target)
		units_to_deploy.append(target.template)
		#gdlint: ignore=private-method-call
		battle_grid_state.get_ref()._remove_unit(target)
		target.unit_killed()  #TODO change this signal to a undo specific as to not mess with future animations and text bubbles

#endregion Subclasses
