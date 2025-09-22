class_name BattleManagerFast
extends BattleManagerFastCpp

## A helper class wrapping C++ battle manager
## and adding useful integration/testing functions

var _integrity_check_move: MoveInfo

## Maps BMFast's unit IDs (in format [army, unit]) and DataUnit
var summon_mapping_cpp2gd: Dictionary = {}
## Maps BMFast's unit IDs (in format [army, unit]) and DataUnit
var summon_mapping_gd2cpp: Dictionary = {}
## Maps BMFast's spell IDs to BattleSpells
var spell_mapping: Array = []

## Maps team ids to BMFast's team ids (BMFast's team ids must be less than max army number)
var team_mapping: Dictionary = {}

## Make a BattleManagerFast for MCTS purposes.
## Parameter tgrid may be null, in which case TileGridFast is created automatically
static func from(bgstate: BattleGridState, tgrid: TileGridFast = null) -> BattleManagerFast:
	var new = BattleManagerFast.new()
	if tgrid == null:
		tgrid = TileGridFast.from(bgstate)
		new.add_child(tgrid)

	new.set_tile_grid(tgrid)
	new.set_current_participant(bgstate.current_army_index)

	new.set_cyclone_constants(
		CFG.BIG_CYCLONE_COUNTER_VALUE,
		CFG.SMALL_CYCLONE_COUNTER_VALUE,
		CFG.CYCLONE_MANA_THRESHOLD,
		BattleGridState.MANA_WELL_POWER
	)

	var max_team = 0

	for army_idx in range(bgstate.armies_in_battle_state.size()):
		var army = bgstate.armies_in_battle_state[army_idx]

		var player_idx = army.army_reference.controller_index
		var player = IM.get_player_by_index(player_idx)
		# TODO temp hack for world battles
		var team = player.team if player else max_team + 10000000
		var team_id = team if team != 0 else (army_idx + 1000000)
		if team_id not in new.team_mapping:
			new.team_mapping[team_id] = max_team
			max_team += 1

		new.set_army_team(army_idx, new.team_mapping[team_id])
		new.set_army_cyclone_timer(army_idx, army.cyclone_timer)

		var martyrs = []
		var martyr_duration = -50

		# Alive unit processing
		for unit_idx in range(army.units.size()):
			var unit: Unit = army.units[unit_idx]
			if unit.dead:
				continue

			new.insert_unit(army_idx, unit_idx, unit.coord, unit.unit_rotation, false)
			new.set_unit_score(army_idx, unit_idx, unit.template.level)
			new.set_unit_mana(army_idx, unit_idx, unit.template.mana)

			for i in range(6):
				new.set_unit_symbol(army_idx, unit_idx, i, unit.template.symbols[i])

			for spell in unit.spells:
				new.insert_spell(army_idx, unit_idx, new.spell_mapping.size(), spell.name)
				new.spell_mapping.push_back(spell)

			for eff in unit.effects:
				match eff.name:
					"Martyr":
						martyrs.push_back(unit_idx)
						martyr_duration = eff.duration_counter
					_:
						new.set_unit_effect(army_idx, unit_idx, eff.name, eff.duration_counter)

		# TODO in future there might potentially be more martyrs simultaneously
		assert(martyrs.size() in [0,1,2], "Unsupported martyr number")
		if martyrs.size() == 2:
			new.set_unit_martyr(army_idx, martyrs[0], martyrs[1], martyr_duration)
		elif martyrs.size() == 1:
			new.set_unit_solo_martyr(army_idx, martyrs[0], martyr_duration)

		# Deployment processing
		for summon_idx in range(army.units_to_deploy.size()):
			var unit = army.units_to_deploy[summon_idx]
			var unit_idx = summon_idx + army.units.size()

			new.insert_unit(army_idx, unit_idx, Vector2i.ZERO, 0, true)
			for i in range(6):
				new.set_unit_symbol(army_idx, unit_idx, i, unit.symbols[i])

			new.summon_mapping_cpp2gd[[army_idx, unit_idx]] = unit
			new.summon_mapping_gd2cpp[unit] = [army_idx, unit_idx]

	new.finish_initialization()

	if bgstate.state == BattleGridState.STATE_FIGHTING:
		new.force_battle_ongoing()
	elif bgstate.state == BattleGridState.STATE_SACRIFICE:
		new.force_battle_sacrifice()

	return new


func set_unit_symbol(army_idx: int, unit_idx: int, symbol_idx: int, symbol: DataSymbol):
	set_unit_symbol_cpp(
		army_idx, unit_idx, symbol_idx,
		symbol.attack_power, symbol.defense_power, symbol.reach,
		symbol.counter_attack, symbol.push_power, symbol.parry, symbol.parry_break
	)

#region Libspear tuple <-> MoveInfo conversion

# Libspear tuple format - [unit_in_current_army_id, position, OPTIONAL spell]
func libspear_tuple_to_move_info(tuple: Array) -> MoveInfo:
	var unit: int = tuple[0]
	var position: Vector2i = tuple[1]

	var unit_position = get_unit_position(get_current_participant(), unit)
	var uid = [get_current_participant(), unit]

	if is_in_sacrifice_phase():
		return MoveInfo.make_sacrifice(unit_position)
	elif is_in_summoning_phase():
		return MoveInfo.make_deploy(summon_mapping_cpp2gd[uid], position)
	elif tuple.size() == 3: # Magic
		return MoveInfo.make_magic(unit_position, position, spell_mapping[tuple[2]])
	else:
		return MoveInfo.make_move(unit_position, position)

func move_info_to_libspear_tuple(move: MoveInfo) -> Array:
	var unit: int
	var pos = move.target_tile_coord

	match move.move_type:
		MoveInfo.TYPE_DEPLOY:
			unit = summon_mapping_gd2cpp[move.deployed_unit][1]
		MoveInfo.TYPE_MOVE:
			unit = get_unit_id_on_position(move.move_source)[1]
		MoveInfo.TYPE_SACRIFICE:
			unit = get_unit_id_on_position(move.move_source)[1]
			pos = Vector2i.ZERO
		MoveInfo.TYPE_MAGIC:
			unit = get_unit_id_on_position(move.move_source)[1]
			return [unit, pos, spell_mapping.find(move.spell)]
		_:
			assert(false, "Unknown move type '%s'" % [move.move_type])

	return [unit, pos]

#endregion

#region Integrity testing

func check_integrity_before_move(bgs: BattleGridState, move: MoveInfo):
	if not CFG.debug_check_bmfast_integrity:
		return

	set_debug_internals(true)

	assert_integrity_check(compare_move_list(bgs), "Integrity check failed before move")
	assert_integrity_check(compare_grid_state(bgs), "Integrity check failed before move")

	if move.move_type == MoveInfo.TYPE_DEPLOY: # Do not check summon after move
		move = null
		return

	var unit = bgs.get_unit(move.move_source)
	var unit_id = bgs.armies_in_battle_state[bgs.current_army_index].units.find(unit)
	assert_integrity_check(unit_id != -1, "BMFast Integrity check failed before move - unit on coords %s not found in fast" % move.move_source)

	play_move(move_info_to_libspear_tuple(move))
	_integrity_check_move = move


func check_integrity_after_move(bgs: BattleGridState):
	if not CFG.debug_check_bmfast_integrity or bgs.state == bgs.STATE_BATTLE_FINISHED:
		return
	#assert(compare_move_list(bgs), "BMFast Integrity check failed after move")

	if _integrity_check_move: # Only check ongoing battle moves
		assert_integrity_check(compare_grid_state(bgs), "Integrity check failed after move")


func assert_integrity_check(condition: bool, message: String):
	if not condition:
		if CFG.debug_save_failed_bmfast_integrity:
			BM._replay_data.save_as("BMFast Mismatch")
		assert(false, "BMFast - %s  - check error log for details" % [message])


func compare_grid_state(bgs: BattleGridState) -> bool:
	var is_ok = true

	if bgs.current_army_index != get_current_participant():
		push_error("BMFast mismatch - current army: slow ", bgs.current_army_index, ", fast ", get_current_participant())
		is_ok = false

	if is_in_sacrifice_phase() and bgs.state != bgs.STATE_SACRIFICE:
		push_error("BMFast mismatch - state mismatch - fast: sacrifice, slow: " + bgs.state)
		is_ok = false

	if is_in_summoning_phase() and bgs.state != bgs.STATE_DEPLOYMENT:
		push_error("BMFast mismatch - state mismatch - fast: summoning, slow: " + bgs.state)
		is_ok = false

	if not is_in_sacrifice_phase() and not is_in_summoning_phase() and bgs.state != bgs.STATE_FIGHTING:
		push_error("BMFast mismatch - state mismatch - fast: fighting, slow: " + bgs.state)
		is_ok = false

	var slow_cyclone_target = bgs.armies_in_battle_state.find(bgs.cyclone_target)
	if get_cyclone_target() != slow_cyclone_target:
		push_error("BMFast mismatch - cyclone target - fast: %s, slow: %s" % [get_cyclone_target(), slow_cyclone_target])
		is_ok = false

	for army_id in range(bgs.armies_in_battle_state.size()):
		var units_nr = get_max_units_in_army()
		var army = bgs.armies_in_battle_state[army_id]

		assert(
			army.units.size() + army.units_to_deploy.size() <= get_max_units_in_army(),
			"No support for more than %s units in fast BM" % [get_max_units_in_army()]
		)

		var cyclone_timer_slow = army.cyclone_timer
		var cyclone_timer_fast = get_army_cyclone_timer(army_id)

		if cyclone_timer_fast != cyclone_timer_slow:
			push_error("BMFast mismatch - cyclone timer for army %s - fast: %s, slow: %s" % [
				army_id, cyclone_timer_fast, cyclone_timer_slow
			])
			is_ok = false

		if army.mana_points != get_army_mana_points(army_id):
			push_error("BMFast mismatch - mana points for army %s - fast: %s, slow: %s" % [
				army_id, get_army_mana_points(army_id), army.mana_points
			])
			is_ok = false

		for unit in army.units:
			var uid = get_unit_id_on_position(unit.coord)
			if uid[1] == -1:
				push_error("BMFast mismatch - unit not present in fast - slow coord: @", unit.coord, "")
				is_ok = false
			elif uid[0] != army_id:
				push_error("BMFast mismatch - unit on slow coord: @", unit.coord, " belongs to army id ", uid[0], ", expected ", army_id)
				is_ok = false

		for unit_id in range(get_max_units_in_army()):
			if not is_unit_alive(army_id, unit_id):
				units_nr -= 1
				continue # probably no need to check summons/dead

			var unit: Unit = bgs.get_unit(get_unit_position(army_id, unit_id))
			if unit == null:
				push_error("BMFast mismatch - unit not present in slow - fast id:", army_id, "/", unit_id, " @", get_unit_position(army_id, unit_id), "")
				is_ok = false
				continue

			var unit_str = "%s/%s @%s,%s" % [army_id, unit_id, unit.coord.x, unit.coord.y]

			if unit.unit_rotation != get_unit_rotation(army_id, unit_id):
				push_error("BMFast mismsatch - unit: id ", unit_str, " slow has rotation ", unit.unit_rotation, \
						   ",  ", " vs fast's rotation ", get_unit_rotation(army_id, unit_id))
				is_ok = false

			for spell in unit.spells:
				# TODO check when there are several instances of the same spell?
				if count_spell(army_id, unit_id, spell.name) != 1:
					push_error("BMFast mismatch - unit id ", unit_str, " fast does not have slow spell ", spell.name)
					is_ok = false

			if get_unit_spell_count(army_id, unit_id) != unit.spells.size():
				push_error("BMFast mismatch - spell count for unit %s - fast %s vs slow %s" \
							% [unit_str, get_unit_spell_count(army_id, unit_id), unit.spells.size()])
				is_ok = false

			if get_unit_effect_count(army_id, unit_id) != unit.effects.size():
				push_error("BMFast mismatch - effect count for unit %s - fast %s vs slow %s" \
							% [unit_str, get_unit_effect_count(army_id, unit_id), unit.effects.size()])
				is_ok = false

			var is_martyr = false
			for eff in unit.effects:
				match eff.name:
					"Martyr":
						is_martyr = true
					_:
						var eff_fast = get_unit_effect(army_id, unit_id, eff.name)
						if not eff_fast:
							push_error("BMFast mismatch - effect '%s' present in slow but not fast" % [eff.name])
							is_ok = false
				var duration_fast = get_unit_effect_duration_counter(army_id, unit_id, eff.name)
				if eff.duration_counter != duration_fast:
					push_error("BMFast mismatch - effect '%s' has duration %s in slow and %s in fast" % [eff.name, eff.duration_counter, duration_fast])
					is_ok = false
			
			# TEMP awaits Maryr code rework
			#if is_martyr != (get_unit_martyr_id(army_id, unit_id) != -1):
				#push_error("BMFast mismatch - martyr status for unit %s - slow %s vs fast %s"
						   #% [unit_str ,is_martyr, get_unit_martyr_id(army_id, unit_id) != -1])
				#is_ok = false

		var units_alive_in_army = army.units.filter(func(x): return not x.dead).size()
		if units_nr != units_alive_in_army:
			push_error("BMFast mismatch - number of units in army ", army_id, ": slow ", units_alive_in_army, ", fast ", units_nr)
			is_ok = false

	return is_ok

func compare_move_list(bgs: BattleGridState) -> bool:
	var is_ok = true

	var fast_moves = get_legal_moves()
	var slow_moves = bgs.get_possible_moves()

	for i in fast_moves:
		var move = libspear_tuple_to_move_info(i)

		if not bgs.is_move_possible(move):
			push_error("BMFast move mismatch - fast action %s (%s) not present in slow" % [move, i])
			is_ok = false

	for i in slow_moves:
		if move_info_to_libspear_tuple(i) not in fast_moves:
			push_error("BMFast move mismatch - slow action %s not present in fast" % [i])
			is_ok = false

	return is_ok

#endregion
