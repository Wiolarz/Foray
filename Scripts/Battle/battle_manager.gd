# Singleton - BM
extends GridNode2D

var _battle_is_ongoing : bool = false

var _battle_grid_state : BattleGridState # GAMEPLAY combat state

var _tile_grid : GenericHexGrid # Grid<TileForm> - VISUALs in a grid
var _unit_to_unit_form : Dictionary # gameplay unit to VISUAL mapping
var _grid_tiles_node : Node2D # parent for tiles VISUAL
var _unit_forms_node : Node2D # parent for units VISUAL
var _border_node : Node2D # parent for border tiles VISUAL
var _move_highlights_node : Node2D

var _battle_ui : BattleUI
var latest_ai_cancel_token : CancellationToken

var _current_summary : DataBattleSummary = null

var _selected_unit : Unit

var _replay_data : BattleReplay
var _replay_is_playing : bool = false
var _replay_move_counter : int = 0
var _replay_number_of_moves : int = 0

var _batch_mode : bool = false # flagged true when recreating game state
var _ai_move_preview : AIMovePreview = null
var _painter_node : BattlePainter

var _scripted_battle : ScriptedBattle

signal move_animation_done()


func _ready():
	## Order of nodes determines their visibility, lower ones are on top of the previous ones.
	_battle_ui = load("res://Scenes/UI/BattleUi.tscn").instantiate()

	_grid_tiles_node = Node2D.new()
	_grid_tiles_node.name = "GRID"
	add_child(_grid_tiles_node)

	_unit_forms_node = Node2D.new()
	_unit_forms_node.name = "UNITS"
	add_child(_unit_forms_node)

	_painter_node = load("res://Scenes/UI/Battle/BattlePlanPainter.tscn").instantiate()
	add_child(_painter_node)

	_move_highlights_node = Node2D.new()
	_move_highlights_node.name = "MOVE_HIGHLIGHTS"
	add_child(_move_highlights_node)

	UI.add_custom_screen(_battle_ui)


func _process(_delta):
	_check_clock_timer_tick()


#region Battle Setup

## x_offset is used to place battle to the right of world map
## replay_template - used in replays to avoid juggling player data
func start_battle(new_armies : Array[Army], battle_map : DataBattleMap, \
		x_offset : float, battle_state : SerializableBattleState = null,
		replay_template : BattleReplay = null,
		scripted_battle : ScriptedBattle = null) -> void:

	assert(_is_clear(), "cannot start battle map, map already loaded")

	if replay_template:
		_replay_data = BattleReplay.from_template(replay_template)
	else:
		_replay_data = BattleReplay.create(new_armies, battle_map)

	_scripted_battle = scripted_battle

	_replay_move_counter = 0

	if not _replay_is_playing and not replay_template:
		_replay_data.save()

	UI.ensure_camera_is_spawned()
	UI.go_to_custom_ui(_battle_ui)

	_battle_is_ongoing = true

	_current_summary = null
	deselect_unit()

	# CORE GAMEPLAY logic initialization
	_battle_grid_state = BattleGridState.create(battle_map, new_armies)

	# GRAPHICS GRID:
	_load_map(battle_map)
	_grid_tiles_node.position.x = x_offset
	horizontal_offset = x_offset
	_battle_ui.load_armies(_battle_grid_state.armies_in_battle_state)

	if battle_state: # recreate state if present
		_batch_mode = true
		for m in battle_state.replay.moves:
			_perform_replay_move(m)
		_batch_mode = false

	var is_spectator = true
	for player in IM.players:
		if player.is_local():
			is_spectator = false

	if is_spectator and CFG.ENABLE_AUTO_BRAIN:
		_enable_ai_preview()

	# Set first player's color
	BG.set_player_colors(get_current_slot_color())

	# first turn does not get a signal emit
	_on_turn_started(_battle_grid_state.get_current_player())

	# Play battle music
	AUDIO.play_music("battle")


func _load_map(map : DataBattleMap) -> void:
	assert(_is_clear(), "cannot load map, map already loaded")
	_tile_grid = GenericHexGrid.new(map.grid_width, map.grid_height, null)
	_unit_to_unit_form.clear()
	for x in range(map.grid_width):
		for y in range(map.grid_height):
			var coord = Vector2i(x, y)
			var data = map.grid_data[x][y] as DataTile
			var tile_form = TileForm.create_battle_tile(data, coord)
			_tile_grid.set_hex(coord, tile_form)
			tile_form.position = to_position(coord)
			_grid_tiles_node.add_child(tile_form)

	if not IM.in_map_editor:
		_border_node = MapBorder.from_map(map)
		add_child(_border_node)


## space needed for battle tiles in global position
func get_bounds_global_position() -> Rect2:
	if _is_clear():
		push_warning("asking not initialized grid for camera bounding box")
		return Rect2(0, 0, 0, 0)
	var top_left_tile_position := get_tile_global_position(Vector2i(0,0))
	var bottom_right_tile_position  := \
			get_tile_global_position(Vector2i(_tile_grid.width-1, _tile_grid.height-1))
	var size : Vector2 = bottom_right_tile_position - top_left_tile_position
	return Rect2(top_left_tile_position, size)

#endregion Battle Setup


#region helpers

func get_current_slot_color() -> DataPlayerColor:
	if not _battle_is_ongoing:
		return CFG.NEUTRAL_COLOR
	var player = _battle_grid_state.get_current_player()
	if not player:
		return CFG.NEUTRAL_COLOR
	return player.get_player_color()


func get_current_player_name() -> String:
	if not _battle_is_ongoing:
		assert(false, "Request current fighting player, while battle is not ongoing")
		return ""
	var player = _battle_grid_state.get_current_player()
	if not player:
		return "Neutral Player"
	return player.get_player_name()


func get_current_turn() -> int:
	return _battle_grid_state.turn_counter


func get_unit_form(coord : Vector2i) -> UnitForm:
	var unit : Unit = _battle_grid_state.get_unit(coord)
	if unit and unit in _unit_to_unit_form:
		return _unit_to_unit_form[unit]
	return null


func get_tile_form(coord : Vector2i) -> TileForm:
	return _tile_grid.get_hex(coord)


## tells if there is battle state that is important and should be serialized
func battle_is_active() -> bool:
	return _battle_is_ongoing


#TODO: simplify
func can_show_battla_camera() -> bool:
	return _battle_is_ongoing


#TODO: WM should remember if its waiting for battle to end or not,
# BM should not care
func should_block_world_interaction() -> bool:
	return _battle_is_ongoing


## converts from coordinates like 3,5 to actual position like 1200,300
func get_tile_global_position(coord : Vector2i) -> Vector2:
	return _tile_grid.get_hex(coord).global_position


## checks if map was cleaned properly, usually used for asserts
func _is_clear() -> bool:
	return _grid_tiles_node.get_child_count() == 0 \
			and _unit_forms_node.get_child_count() == 0 \
			and _tile_grid == null

#endregion helpers


#region Ongoing battle

func _on_turn_started(player : Player) -> void:
	if not _battle_is_ongoing:
		return

	if _scripted_battle:
		var current_event := BattleEventDescription.generate_current_battle_event(_battle_grid_state)
		_scripted_battle.show_text_bubbles(current_event)

	_battle_ui.start_player_turn(_battle_grid_state.current_army_index)
	if _replay_is_playing:
		_battle_ui.update_replay_controls(_replay_move_counter, _replay_number_of_moves)

	if not player:
		print("uncontrolled army's turn")
		return

	# trigger AI analysis
	print("your move %s - %s" % [player.get_player_name(), player.get_player_color().name])

	if player.bot_engine and not NET.client: # AI is simulated on server only
		print("AI starts thinking")

		var my_cancel_token = CancellationToken.new()
		#assert(latest_ai_cancel_token == null)
		latest_ai_cancel_token = my_cancel_token

		var bot = player.bot_engine

		var thinking_begin_s = Time.get_ticks_msec() / 1000.0
		var move = await bot.choose_move(_battle_grid_state)
		await _ai_thinking_delay(thinking_begin_s) # moving too fast feels weird

		bot.cleanup_after_move()
		if _battle_grid_state == null: # Player quit to main menu before finishing
			return

		if not my_cancel_token.is_canceled():
			assert(_battle_grid_state.is_move_possible(move), "AI tried to perform an invalid move")
			_perform_move_info(move)
			latest_ai_cancel_token = null


func perform_network_move(move_info : MoveInfo) -> void:
	_perform_move_info(move_info)


func _perform_replay_move(move_info : MoveInfo) -> void:
	_battle_grid_state.set_displayed_time_left_ms(move_info.time_left_ms)
	_perform_move_info(move_info)


func undo() -> void:
	if _replay_data.moves.is_empty():
		return
	if not battle_is_active():
		return

	cancel_pending_ai_move()

	var last_move : MoveInfo = _replay_data.moves.pop_back()
	var revived_units : Array[Unit] = _battle_grid_state.undo(last_move)

	# VISUALS
	for unit in revived_units:
		_on_unit_deployment(unit)  # revive
	_battle_ui.refresh_after_undo(_battle_grid_state.is_during_deployment_phase())
	_end_move()
	ANIM.fast_forward()


## STUB
func redo() -> void:
	push_warning("not implemented")
	pass


## IMPORTANT FUNCTION -> called when tile is clicked
func grid_input(coord : Vector2i) -> void:
	if not _battle_is_ongoing:
		print("battle finished, input ignored")
		return

	if _replay_is_playing:
		_painter_node.erase()  # TODO verify if that's a proper fix to allow drawing in replays
		print("replay playing, input ignored")
		return

	# any normal input removes all drawn arrows
	_painter_node.erase()

	var current_player : Player =  _battle_grid_state.get_current_player()
	if current_player != null and current_player.bot_engine:
		print("ai playing, input ignored")
		return

	if not current_player.is_local():
		print("Attempt to play a move of an another player")
		return

	var move_info : MoveInfo

	match _battle_grid_state.state:
		BattleGridState.STATE_DEPLOYMENT:
			move_info = _grid_input_deployment(coord)
		BattleGridState.STATE_FIGHTING:
			if _battle_ui.selected_spell == null:
				move_info = _grid_input_fighting(coord)
			else:
				move_info = _grid_input_magic(coord)
		BattleGridState.STATE_SACRIFICE:
			move_info = _grid_input_sacrifice(coord)

	if move_info:
		if NET.client:
			NET.client.queue_request_move(move_info)
			return # dont perform move, send it to server

		_perform_move_info(move_info)


func _check_for_stalemate() -> bool:
	var limit = BattleGridState.STALEMATE_TURN_REPEATS

	# if number of the armies were to change during last few moves, then it wouldn't be a stalemate
	var alive_armies = []
	for army in _battle_grid_state.armies_in_battle_state:
		if army.can_fight():
			alive_armies.append(army)

	# equation determines the shortest scenario to achieve a stalemate
	# later we jump back X move behind, so it makes it safe to do so
	if _replay_data.moves.size() < limit * alive_armies.size() * 2:
		return false

	var go_back_value = limit * alive_armies.size() + 1
	for player_idx in range(alive_armies.size()):
		var old_move = _replay_data.moves[-go_back_value - player_idx]
		var new_move = _replay_data.moves[-player_idx - 1]

		if new_move.move_type != MoveInfo.TYPE_MOVE or old_move.move_type != new_move.move_type:
			return false
		if old_move.move_source != new_move.move_source or \
			old_move.target_tile_coord != new_move.target_tile_coord:
				return false
	return true


func _end_move() -> void:
	if _battle_grid_state.battle_is_ongoing():
		if _check_for_stalemate():
			_battle_grid_state.end_stalemate() # could end the battle

	if _battle_grid_state.battle_is_ongoing():
		if _ai_move_preview:
			_ai_move_preview.update(_battle_grid_state)

		_battle_ui.update_mana() # TEMP placement here
		_on_turn_started(_battle_grid_state.get_current_player())
	else:
		_on_battle_ended()

#endregion Ongoing battle


#region AI Support

func cancel_pending_ai_move() ->  void:
	if latest_ai_cancel_token:
		latest_ai_cancel_token.cancel()
		latest_ai_cancel_token = null


func _ai_thinking_delay(thinking_begin_s) -> void:
	var max_seconds = CFG.bot_speed_frames / 60.0
	var seconds = max(0.01, max_seconds - (Time.get_ticks_msec()/1000.0 - thinking_begin_s))
	await get_tree().create_timer(seconds).timeout
	while IM.is_game_paused() or CFG.bot_speed_frames == CFG.BotSpeed.FREEZE:
		await get_tree().create_timer(0.1).timeout


func ai_move() -> void:
	if latest_ai_cancel_token:
		push_warning("ai is already moving, dont stack two simultaneous ai moves race")
		return

	if _replay_is_playing:
		return

	var move := AiBotStateRandom.choose_move_static(_battle_grid_state)
	_perform_move_info(move)

#endregion AI Support


#region Deployment Phase

## handles spawning unit form when unit is spawned on a gameplay map
## also connects animation related signals
func _on_unit_deployment(unit : Unit) -> void:
	var form := UnitForm.create(unit)
	_unit_forms_node.add_child(form)
	_unit_to_unit_form[unit] = form
	form.set_effects()  # VISUAL makes hero passives visible on the unit

	# apply correct BM position offset in world battles
	form.global_position = get_tile_global_position(unit.coord)

	var is_deployment_phase_over : bool = not _battle_grid_state.is_during_deployment_phase()
	_battle_ui.unit_deployed(is_deployment_phase_over)
	if is_deployment_phase_over:
		for row : Array in _tile_grid.hexes:
			for tile : TileForm in row:
				# TODO replace it with better map editor features
				if tile.type in ["1_player_spawn", "2_player_spawn", "3_player_spawn", "4_player_spawn"]:
					tile.get_node("Sprite2D").texture = load("res://Art/battle_map/grass_tile.png")

	# TODO imo should be refactored
	unit.unit_magic_effect.connect(func(_effect: BattleMagicEffect): _on_unit_magic_effect(unit))  # spell icons UI

	unit.unit_died.connect(form.anim_die)
	unit.unit_died.connect(_on_unit_death)  # TEXT BUBBLES
	unit.unit_turned.connect(form.anim_turn)
	unit.unit_moved.connect(form.anim_move)
	unit.unit_magic_effect.connect(form.anim_magic)  # STUB


	unit.unit_captured_mana.connect(capture_mana_well.bind(unit))  # Places flag on mana well tile

	# Symbol animations
	unit.unit_is_pushing.connect(form.anim_symbol.bind(CFG.SymbolAnimationType.MELEE_ATTACK))
	unit.unit_is_slashing.connect(form.anim_symbol.bind(CFG.SymbolAnimationType.MELEE_ATTACK))
	unit.unit_is_counter_attacking.connect(form.anim_symbol.bind(CFG.SymbolAnimationType.MELEE_ATTACK))

	unit.unit_is_shooting.connect(func(side : int, attacker_coord : Vector2i):
		form.anim_symbol(side, CFG.SymbolAnimationType.TELEPORTING_PROJECTILE, attacker_coord)
	)
	unit.unit_is_blocking.connect(func(side : int, attacker_coord : Vector2i):
		form.anim_symbol(side, CFG.SymbolAnimationType.BLOCK, attacker_coord)
	)


## handles player input while during the deployment phase
func _grid_input_deployment(coord : Vector2i) -> MoveInfo:
	assert(_battle_grid_state.state == _battle_grid_state.STATE_DEPLOYMENT, \
			"_grid_input_deployment called in an incorrect state")

	if _battle_ui._selected_unit_pointer == null:
		return null # no unit selected to deploy on ui

	if not _battle_grid_state.current_player_can_deploy_on(coord):
		return null

	print(NET.get_role_name(), " input - deploying unit")
	return MoveInfo.make_deploy(_battle_ui._selected_unit_pointer, coord)


#endregion Deployment Phase


#region Mana Cyclone Timer

func get_cyclone_target() -> Player:
	return _battle_grid_state.cyclone_get_current_target()


func get_cyclone_timer() -> int:
	return _battle_grid_state.cyclone_get_current_target_turns_left()


func get_player_mana(player : Player) -> int:
	var player_army = _battle_grid_state._get_player_army(player) # TEMP? or should it be public
	return player_army.mana_points


## visually captures the well
## unit get's their coord updated during animation
func capture_mana_well(coord : Vector2i, unit : Unit) -> void:

	var controller_sprite = _tile_grid.get_hex(coord).get_node("ControlerSprite")
	controller_sprite.visible = true
	var data_color : DataPlayerColor = unit.controller.get_player_color()

	var color_texture_name : String = data_color.hexagon_texture
	var path = "%s%s.png" % [CFG.PLAYER_COLORS_PATH, color_texture_name]
	var texture = load(path) as Texture2D
	assert(texture, "failed to load background " + path)
	controller_sprite.texture = texture

#endregion Mana Cyclone Timer


#region Fighting Phase

## Turn timer unit sacrifice (Stalemate prevention mechanic)
func _grid_input_sacrifice(coord : Vector2i) -> MoveInfo:
	## TODO:
	## input should be locked to the person that is bound to make a sacrifice,
	## which could be a different player than a current one also it occurs at round start

	assert(_battle_grid_state.state == _battle_grid_state.STATE_SACRIFICE, \
			"_grid_input_fighting called in an incorrect state")

	var new_unit : Unit = _battle_grid_state.get_unit(coord)
	if new_unit and new_unit.army_in_battle == _battle_grid_state.cyclone_target:
		return MoveInfo.make_sacrifice(coord)

	return null


## Selected Unit -> instead of moving casts a spell
func _grid_input_magic(coord : Vector2i) -> MoveInfo:
	assert(_battle_grid_state.state == _battle_grid_state.STATE_FIGHTING, \
			"_grid_input_magic called in an incorrect state")

	if _battle_ui.selected_spell == null:
		return null # no spell selected to cast on ui

	if not _battle_grid_state.is_spell_target_valid(_selected_unit, coord, _battle_ui.selected_spell):
		return null

	var move_info = MoveInfo.make_magic(_selected_unit.coord, coord, _battle_ui.selected_spell)
	deselect_unit()

	return move_info


## Either Unit selection or a command to move
func _grid_input_fighting(coord : Vector2i) -> MoveInfo:
	assert(_battle_grid_state.state == _battle_grid_state.STATE_FIGHTING, \
			"_grid_input_fighting called in an incorrect state")


	if _try_select_unit(coord) or _selected_unit == null:
		# used in scenarios:
		# - selected a new unit
		# - clicked a tile with no ally units, when no unit was selected
		return null

	# get_move_direction() returns MOVE_IS_INVALID on impossible moves, handles scenarios like
	# - spot is not adjacent (MOVE_IS_INVALID)
	# - spot is empty (dir)
	# - spot is not movable (MOVE_IS_INVALID)
	# - there is an enemy that can be killed by the move (dir)
	# - there is enemy that cannot be killed by the move (MOVE_IS_INVALID)
	if not _battle_grid_state.is_move_valid(_selected_unit, coord):
		return null

	var move_info = MoveInfo.make_move(_selected_unit.coord, coord)
	deselect_unit()

	return move_info


## Select friendly Unit on a given coord [br]
## returns true if unit was selected
func _try_select_unit(coord : Vector2i) -> bool:
	var new_unit : Unit = _battle_grid_state.get_unit(coord)
	if not new_unit:
		return false
	if new_unit.controller != _battle_grid_state.get_current_player():
		return false

	if new_unit == _selected_unit:  # Selecting the same unit twice deselects it
		deselect_unit()
		return false

	# deselect visually old unit if new one selected
	if _selected_unit:
		deselect_unit()

	_selected_unit = new_unit
	_unit_to_unit_form[_selected_unit].set_selected(true)
	update_move_highlights()

	if _scripted_battle:
		var current_event := BattleEventDescription.generate_current_battle_event(_battle_grid_state)
		_scripted_battle.show_text_bubbles(current_event)

	# attempt to display spells available to selected unit
	_show_spells(_selected_unit)

	return true


## Main way to deselect unit -> use every time, its safe
func deselect_unit() -> void:
	if _selected_unit and _selected_unit in _unit_to_unit_form:
		_unit_to_unit_form[_selected_unit].set_selected(false)
	_selected_unit = null
	_battle_ui.selected_spell = null
	_battle_ui.reset_spells()
	update_move_highlights()


func update_move_highlights():
	Helpers.remove_all_children(_move_highlights_node)
	if not _selected_unit:
		return

	# Process spell moves if spell selected, TODO magic consequences, check if BGS cloning is viable
	if _battle_ui and _battle_ui.selected_spell != null:

		var magic_moves = _battle_grid_state._get_magic_moves(
			_selected_unit,
			_battle_ui.selected_spell
		)

		for move in magic_moves:
			var highlight = CFG.PLAN_POINTER_SCENE.instantiate() # TODO maybe dedicated highlight gfx
			highlight.position = BM.to_position(move.target_tile_coord)
			highlight.z_index = 2 # Render on top of the selected unit too
			_move_highlights_node.add_child(highlight)
		return

	for move in _battle_grid_state.get_possible_moves():
		if move.move_source != _selected_unit.coord:
			continue

		if move.move_type != MoveInfo.TYPE_MOVE: # TODO highlighting other move types
			continue

		var color: Color

		match _battle_grid_state.get_move_consequences(move):
			BattleGridState.MoveConsequences.NONE:
				color = Color.WHITE_SMOKE
			BattleGridState.MoveConsequences.KILL:
				color = Color.LIGHT_GREEN
			BattleGridState.MoveConsequences.DEATH:
				color = Color.INDIAN_RED
			BattleGridState.MoveConsequences.KAMIKAZE:
				color = Color.YELLOW
			var x:
				assert(false, "Unimplemented move consequence type %s" % [x])

		var offset = move.move_source - move.target_tile_coord
		var highlight = CFG.MOVE_HIGHLIGHT_SCENE.instantiate()
		highlight.modulate = color
		highlight.position = BM.to_position(move.target_tile_coord)
		highlight.rotation = GenericHexGrid.DIRECTION_TO_OFFSET.find(offset) * PI/3
		_move_highlights_node.add_child(highlight)


func _show_spells(unit : Unit) -> void:
	if unit.spells.size() == 0:
		return

	#TODO? check here if selected unit is preview mode only (controlled by another player)
	_battle_ui.load_spells(_battle_grid_state.current_army_index , unit.spells)


## Executes given move_info [br]
## used by input moves, replays, network and AI
func _perform_move_info(move_info : MoveInfo) -> void:
	if not _battle_is_ongoing:
		return
	print(NET.get_role_name(), " performing move ", move_info)

	ANIM.fast_forward()
	var bg_transition_tween = ANIM.subtween(
		ANIM.main_tween(),
		ANIM.TweenPlaybackSettings.always_smooth()
	)

	_replay_move_counter += 1

	if not _replay_is_playing:
		_replay_data.record_move(move_info, get_current_time_left_ms())
		_replay_data.save()

	if NET.server:
		NET.server.broadcast_move(move_info)

	match move_info.move_type:
		MoveInfo.TYPE_MOVE, MoveInfo.TYPE_SACRIFICE, MoveInfo.TYPE_MAGIC:
			_battle_grid_state.move_info_execute(move_info)

			# TODO verify if it's a good enough solution for summoning units
			# as it's hard to create new visible units within battle grid state
			if move_info.move_type == MoveInfo.TYPE_MAGIC and move_info.spell.name in ["Summon Dryad"]:
				_on_unit_deployment(_battle_grid_state.get_unit(move_info.target_tile_coord))


		MoveInfo.TYPE_DEPLOY:
			var unit : Unit = _battle_grid_state.move_info_deploy_unit(move_info)
			_on_unit_deployment(unit)

		_ :
			assert(false, "Move move_type not supported in perform, " + str(move_info.move_type))

	# Make sure there's anything to tween to avoid errors
	ANIM.main_tween().parallel().tween_interval(0.01)
	# When the animation's done, emit a signal
	ANIM.main_tween().tween_callback(func(): move_animation_done.emit())
	# Play the recorded animation
	ANIM.main_tween().play()

	BG.set_player_colors(get_current_slot_color(), bg_transition_tween)


	_end_move()

#endregion Fighting Phase


#region Battle End

func close_when_quitting_game() -> void:
	deselect_unit()
	_battle_ui.hide_replay_controls()
	_turn_off_battle_ui()
	_reset_grid_and_unit_forms()
	_disable_ai_preview()

	_replay_is_playing = false # revert to default value for the next battle


## called when battle simulation decided battle was won
func _on_battle_ended() -> void:
	print("ending battle")
	if not _battle_is_ongoing:
		assert(false, "battle ended when it was not ongoing...")
		return
	_battle_is_ongoing = false

	deselect_unit()

	_disable_ai_preview()
	_battle_ui.update_mana()

	await get_tree().create_timer(2).timeout # TEMP, don't exit immediately # TODO get signal from last animation ending

	_current_summary = _create_summary()
	if not _replay_is_playing:
		_replay_data.summary = _current_summary
		_replay_data.save()

	if WM.world_game_is_active():
		# as battle may lead to the world victory condition
		# it would deactivate the world,
		# in that case world summary will be generated by the WM victory check
		_close_battle_and_return()

		# show battle summary over world map
		UI.ui_overlay.show_battle_summary(_current_summary, null)
	elif IM.is_city_defense_active:
		_end_city_battle()
	elif _replay_is_playing:
		_battle_ui.update_replay_controls(_replay_number_of_moves, _replay_number_of_moves, _current_summary)
		# do not exit immediately
	else:
		AUDIO.play_music("victory")
		UI.ui_overlay.show_battle_summary(_current_summary, _close_custom_battle)


## Ends battle in World game mode
func _close_battle_and_return() -> void:
	UI.switch_camera()  # switches camera back to world

	var state_for_world = _battle_grid_state.armies_in_battle_state

	close_when_quitting_game()
	WM.end_of_battle(state_for_world)


func _end_city_battle() -> void:
	var armies : Array[BattleGridState.ArmyInBattleState] = _battle_grid_state.armies_in_battle_state
	close_when_quitting_game()
	IM.end_city_defense_battle(armies)
	IM.go_to_main_menu()


func _close_custom_battle() -> void:
	close_when_quitting_game()
	IM.go_to_main_menu()


func _turn_off_battle_ui() -> void:
	_painter_node.erase()
	_battle_ui.hide()


func _reset_grid_and_unit_forms() -> void:
	_battle_is_ongoing = false
	_tile_grid = null
	_unit_to_unit_form.clear()
	Helpers.remove_all_children(_grid_tiles_node)
	Helpers.remove_all_children(_unit_forms_node)
	if _border_node:
		_border_node.queue_free()
		_border_node = null
	_battle_grid_state = null


## Major function which fully generates information panel at the end of the battle
func _create_summary() -> DataBattleSummary:
	var summary := DataBattleSummary.new()

	var armies_in_battle_state := _battle_grid_state.armies_in_battle_state

	var winning_team : int
	var winning_team_players : Array[Player] = []
	# Search for winning team
	for army_in_battle in armies_in_battle_state:
		if army_in_battle.can_fight():
			winning_team = army_in_battle.team
			break

	# Generate information for every player
	for army_in_battle in armies_in_battle_state:
		var player_stats := DataBattleSummaryPlayer.new()

		var temp_points : int = 0
		# Generate casulties info
		if army_in_battle.dead_units.size() == 0:
			player_stats.losses = "< none >"
		else:
			for dead in army_in_battle.dead_units:
				var unit_description = "%s\n" % dead.unit_name
				player_stats.losses += unit_description
				temp_points += dead.level

		var army_controller_index : int = army_in_battle.army_reference.controller_index
		var army_controller = IM.get_player_by_index(army_controller_index)

		# generates player names for their info column
		player_stats.player_description = army_controller.get_full_player_description() + " " + str(temp_points)

		if army_in_battle.team == winning_team:
			player_stats.state = "winner"
			winning_team_players.append(army_controller)

			# TEMP solution - better color system described in TODO notes
			var color_description = CFG.NEUTRAL_COLOR
			if army_controller:
				color_description = army_controller.get_player_color()
			summary.color = color_description.color
		else:
			player_stats.state = "loser"
		summary.players.append(player_stats)

	# Summary title creation
	assert(winning_team_players.size() > 0, "Battle resulted in no winners")
	var team_name = 'Neutral'
	if winning_team_players[0]: # neutral is null, so we check
		team_name = "Team %s" % winning_team_players[0].team
	summary.title = "%s wins" % [team_name]
	var sep = " : "
	for player in winning_team_players:
		if not player: # neutral
			continue
		summary.title += sep + player.get_player_color().name
		sep = ", "

	return summary

#endregion Battle End


#region Replays

## Plays a replay and returns to the normal state afterwards
func perform_replay(replay : BattleReplay) -> void:
	_replay_is_playing = true # _replay_is_playing is reset in close_when_quitting_game
	_battle_ui.show_replay_controls()
	_battle_grid_state.set_clock_enabled(false)
	_replay_number_of_moves = replay.moves.size()

	for m in replay.moves:
		if not _battle_is_ongoing:
			return # terminating battle while watching
		_perform_replay_move(m)
		await _replay_move_delay()


func _replay_move_delay() -> void:
	var begin = Time.get_ticks_msec()
	await move_animation_done

	var elapsed_ms = Time.get_ticks_msec() - begin
	# Minimal allowed animation duration - 1 second in normal speed
	var min_duration = CFG.bot_speed_frames / CFG.BotSpeed.NORMAL
	var delay = max(min_duration - elapsed_ms/1000.0, min_duration/10.0)
	await get_tree().create_timer(delay).timeout

	while IM.is_game_paused() or CFG.bot_speed_frames == CFG.BotSpeed.FREEZE:
		await get_tree().create_timer(0.1).timeout
		if not _battle_is_ongoing:
			return # terminating battle while watching


## gets replay of current battle, but containing only moves -- used in
## serialization of whole game state
func get_ripped_replay() -> BattleReplay:
	var result = BattleReplay.new()
	result.moves = _replay_data.moves.duplicate()
	return result

#endregion Replays


#region cheats

func force_win_battle():
	_battle_grid_state.force_win_battle()
	_end_move()


func force_surrender():
	_battle_grid_state.force_surrender()
	_end_move()


func _enable_ai_preview():
	if not _battle_grid_state:
		push_error("Failed to enahle AI preview - _battle_grid_state == null")
		return

	if _ai_move_preview:
		return

	_ai_move_preview = AIMovePreview.new()
	add_child(_ai_move_preview)
	_ai_move_preview.name = "AIMovePreview"
	_ai_move_preview.update(_battle_grid_state)


func _disable_ai_preview():
	if _ai_move_preview:
		_ai_move_preview.queue_free()
		_ai_move_preview = null


func toggle_ai_preview():
	if _ai_move_preview:
		_disable_ai_preview()
	else:
		_enable_ai_preview()

#endregion cheats


#region map editor

func load_editor_map(map : DataBattleMap) -> void:
	_load_map(map)


func unload_for_editor() -> void:
	_reset_grid_and_unit_forms()


func paint(coord : Vector2i, brush : DataTile) -> void:
	(_tile_grid.get_hex(coord) as TileForm).paint(brush)


func editor_get_hexes_copy_as_array() -> Array: #Array[Array[TileForm]]
	return _tile_grid.hexes.duplicate(true)

#endregion map editor


#region Chess clock

## called every frame by _process
func _check_clock_timer_tick() -> void:
	if not _battle_grid_state or not _battle_grid_state.battle_is_ongoing():
		return # no battle
	if _battle_grid_state.get_current_time_left() > 0:
		return # player still has time

	_battle_grid_state.surrender_on_timeout()
	_end_move()

## safe clock getter
func get_current_time_left_ms() -> int:
	if _battle_grid_state && _battle_grid_state.battle_is_ongoing():
		return _battle_grid_state.get_current_time_left()
	return 0

#endregion Chess clock


#region Painting

func planning_input(tile_coord : Vector2i, is_it_pressed : bool) -> void:
	_painter_node.planning_input(tile_coord, is_it_pressed)

#endregion Painting


#region UI

func _on_unit_magic_effect(unit : Unit) -> void:
	_unit_to_unit_form[unit].set_effects()

#endregion UI


#region Scripted Battles

func _on_unit_death() -> void:
	if not _scripted_battle:
		return

	var current_event := BattleEventDescription.generate_current_battle_event(_battle_grid_state)
	_scripted_battle.show_text_bubbles(current_event)

#endregion Scripted Battles
