class_name BattleUI
extends CanvasLayer

@export var deployment_unit_button_size = 200.0

@onready var players_box : BoxContainer = $TopR/PlayersContainer/Players

@onready var units_box : BoxContainer = $BottomC/Units

@onready var camera_button : Button = $TopL/SwitchCamera


@onready var clock = $TopC/TurnsBG/VBox/ClockLeft
@onready var turns = $TopC/TurnsBG/VBox/TurnCount

@onready var cyclone = $TopC/CycloneTimer/VBox/CycloneTarget

@onready var book = $SpellBook

@onready var chat = $BottomC/GameChat

@onready var replay_controls = $ReplayControls
@onready var replay_move_count = $ReplayControls/MoveCount
@onready var replay_status = $ReplayControls/Status
@onready var replay_show_summary = $ReplayControls/ShowSummary

# announcement nodes
@onready var announcement_sacrifice = $SacrificeAnnouncement
@onready var announcement_sacrifice_player_name_label = $SacrificeAnnouncement/CycloneTarget
@onready var announcement_end_of_deployment_phase = $EndDeploymentPhaseAnnouncement
@onready var announcement_end_of_deployment_phase_player_name_label = $EndDeploymentPhaseAnnouncement/FirstPlayerToMoveName

var fighting_players_idx = []
var armies_reference : Array[BattleGridState.ArmyInBattleState]

var current_player : int = 0


## used only for deployment unit tiles, points to currently selected unit/unit-button in deployment
## bar
var _selected_unit_pointer : DataUnit = null
var _selected_unit_button_pointer : BaseButton = null

## used only for deployment unit tiles, points to currently hovered unit button in deployment bar
## (same set of buttons as _`selected_unit_button_pointer` points to
var _hovered_unit_button_pointer : BaseButton = null

## used for grid hovered units and map tiles
var _hovered_unit_form_pointer : UnitForm = null
var _hovered_tile_form_pointer : TileForm = null

var selected_spell : BattleSpell = null
var selected_spell_button : TextureButton = null

# TEMP until update_cyclone() refactor
var _shown_sacrifice_announcement : bool = false

#region INIT

## Cleans UI
func _ready():
	for child in get_children():
		child.show()
	$TextBubble.hide()
	replay_controls.hide()


func load_armies(army_list : Array[BattleGridState.ArmyInBattleState]):
	# Disable "Switch camera" button for non world map gameplay
	var disable_switch_camera : bool = IM.game_setup_info.game_mode != GameSetupInfo.GameMode.WORLD
	camera_button.disabled = disable_switch_camera
	camera_button.visible = not disable_switch_camera

	# save armies
	armies_reference = army_list

	# removing placeholder elements
	while players_box.get_child_count() > 1:
		var c = players_box.get_child(1)
		c.queue_free()
		players_box.remove_child(c)

	units_box.show()
	fighting_players_idx = []
	var idx = 0
	for army in army_list:
		var controller = IM.get_player_by_index(army.army_reference.controller_index)
		fighting_players_idx.append(army.army_reference.controller_index)
		# create player buttons
		var button = Button.new()
		button.text = get_text_for(controller, idx == 0)
		if controller:
			button.modulate = controller.get_player_color().color
		else:
			button.modulate = Color.GRAY
		button.pressed.connect(func select(): on_player_selected(idx, true))
		players_box.add_child(button)
		idx += 1

#endregion INIT


func _process(_delta):
	if BM.battle_is_active():
		update_clock()
		update_cyclone()  # TODO move it to signal that a turn has ended
	force_hover_refresh()


func update_mana() -> void:
	var i = -1
	var temp_skip_label = true
	for player_button in players_box.get_children():
		if temp_skip_label:
			temp_skip_label = false
			continue
		i += 1
		var player_idx = fighting_players_idx[i]
		player_button.text = get_text_for(IM.get_player_by_index(player_idx), false)  # TEMP func doesn't know if a player was selected


func update_cyclone():
	var timer : int = BM.get_cyclone_timer()
	var target : Player = BM.get_cyclone_target()

	#TEMP
	var target_color = target.get_player_color()
	cyclone.modulate = target_color.color


	if timer == 0:
		cyclone.text = "%s Sacrifice" % [target_color.name]
		if not _shown_sacrifice_announcement:
			_shown_sacrifice_announcement = true
			# show sacrifice announcement
			announcement_sacrifice_player_name_label.text = BM.get_current_player_name()
			announcement_sacrifice.modulate = BM.get_current_slot_color().color
			#IM.get_player_by_index(army.army_reference.controller_index)

			announcement_sacrifice.modulate.a = 1
			var tween = ANIM.ui_tween()
			tween.tween_interval(2)
			tween.tween_property(announcement_sacrifice, "modulate:a", 0, 1)
			ANIM.play_tween(tween, ANIM.TweenPlaybackSettings.speed_independent())
	else:
		cyclone.text = "%s %d turns" % [target_color.name, timer]
		_shown_sacrifice_announcement = false


func update_clock() -> void:
	var miliseconds_left = BM.get_current_time_left_ms()
	var seconds = miliseconds_left/1000.0
	var minutes = floor(seconds / 60)
	seconds -= minutes * 60
	var ms = 1000*(seconds-floor(seconds))

	clock.text = "%2.0f : %02.0f : %03.0f" % [minutes, floor(seconds), ms]
	clock.modulate = BM.get_current_slot_color().color

	turns.text = "Turn %d" % [BM.get_current_turn()]


func get_text_for(controller : Player, selected : bool):
	var prefix = " > " if selected else ""
	var player_name = "Neutral"
	if controller:
		player_name = controller.get_player_name()
	return prefix + "Player " + player_name + "_" + str(BM.get_player_mana(controller))


#region Replay controls

func show_replay_controls():
	replay_controls.visible = true
	chat.visible = false


func hide_replay_controls():
	replay_controls.visible = false
	chat.visible = true


func update_replay_controls(move_nr: int, total_replay_moves: int, summary: DataBattleSummary = null):
	replay_move_count.text = "%d/%d" % [move_nr, total_replay_moves]
	if move_nr != total_replay_moves:
		replay_status.text = ""
	elif summary:
		replay_status.text = "Battle ended - all enemy units killed"
	else:
		replay_status.text = "Battle ended - timeout"

	for i in replay_show_summary.pressed.get_connections():
		replay_show_summary.pressed.disconnect(i.callable)

	if summary:
		replay_show_summary.disabled = false
		replay_show_summary.pressed.connect(
			UI.ui_overlay.show_battle_summary.bind(summary, null)
		)
	else:
		replay_show_summary.disabled = true


func _on_pause_pressed():
	CFG.animation_speed_frames = CFG.AnimationSpeed.NORMAL
	CFG.bot_speed_frames = CFG.BotSpeed.FREEZE


func _on_step_pressed():
	# TODO improve/un-DRUTify playback (especially step) controls
	CFG.animation_speed_frames = CFG.AnimationSpeed.NORMAL
	CFG.bot_speed_frames = CFG.BotSpeed.NORMAL
	await get_tree().create_timer(0.1).timeout
	CFG.bot_speed_frames = CFG.BotSpeed.FREEZE


func _on_play_pressed():
	CFG.animation_speed_frames = CFG.AnimationSpeed.NORMAL
	CFG.bot_speed_frames = CFG.BotSpeed.NORMAL


func _on_fast_pressed():
	CFG.animation_speed_frames = CFG.AnimationSpeed.INSTANT
	CFG.bot_speed_frames = CFG.BotSpeed.FAST

#endregion Replay Controls


#region Deployment Phase

func on_player_selected(army_index : int, preview : bool = false):
	_selected_unit_pointer = null
	_selected_unit_button_pointer = null

	if not preview:
		current_player = army_index

	for i in range(armies_reference.size()):
		var is_currently_active := (i == current_player)
		var controller_index = armies_reference[i].army_reference.controller_index
		var controller = IM.get_player_by_index(controller_index)
		var button := players_box.get_child(i + 1) as Button
		button.text = get_text_for(controller, is_currently_active)


	# clean bottom row
	for old_buttons in units_box.get_children():
		old_buttons.queue_free()

	var units_controller_index = armies_reference[army_index].army_reference.controller_index
	var units_controller : Player = IM.get_player_by_index(units_controller_index)
	var bg_color : DataPlayerColor = CFG.NEUTRAL_COLOR
	if units_controller:
		bg_color = units_controller.get_player_color()
	for unit in armies_reference[army_index].units_to_deploy:
		# here is the place where unit buttons for deployment are

		var button := TextureButton.new()
		button.texture_normal = CFG.DEPLOY_BUTTON_TEXTURE
		button.custom_minimum_size = Vector2.ONE * deployment_unit_button_size
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true

		var unit_display := UnitForm.create_for_deployment_ui(unit, bg_color)
		unit_display.position = button.texture_normal.get_size()/2
		var center_container = CenterContainer.new()
		button.add_child(center_container)
		center_container.add_child(unit_display)
		center_container.set_anchors_preset(Control.LayoutPreset.PRESET_CENTER)
		center_container.name = "Center"
		unit_display.name = "UnitForm"
		unit_display.position = Vector2.ZERO

		# TEMP need to find out good way to calculate scale, the constant number
		# here was find empirically
		var calculated_scale = 0.00058 * deployment_unit_button_size
		unit_display.scale = Vector2.ONE * calculated_scale

		units_box.add_child(button)
		var lambda = func on_click():
			# TODO for later: move these lambdas outside to increase readability
			if (current_player != army_index):
				return
			if _selected_unit_button_pointer:  # Deselects previously selected unit
				_selected_unit_button_pointer.get_node("Center/UnitForm").set_selected(false)

			if _selected_unit_button_pointer == button: # Selecting the same unit twice deselects it
				_selected_unit_pointer = null
				_selected_unit_button_pointer = null
			else:
				_selected_unit_pointer = unit
				_selected_unit_button_pointer = button
				_selected_unit_button_pointer.get_node("Center/UnitForm").set_selected(true)
		button.pressed.connect(lambda)

		var lambda_hover = func(is_hovered : bool):
			# TODO for later: move these lambdas outside to increase readability
			if _hovered_unit_button_pointer:
				_hovered_unit_button_pointer.get_node("Center/UnitForm").set_hovered(false)

			if is_hovered:
				_hovered_unit_button_pointer = button
				_hovered_unit_button_pointer.get_node("Center/UnitForm").set_hovered(true)
			else:
				_hovered_unit_button_pointer = null
		button.mouse_entered.connect(lambda_hover.bind(true))
		button.mouse_exited.connect(lambda_hover.bind(false))


func unit_deployed(deployment_phase_end : bool):
	_selected_unit_pointer = null
	_selected_unit_button_pointer = null

	if deployment_phase_end:
		announcement_end_of_deployment_phase_player_name_label.text = BM.get_current_player_name()
		announcement_end_of_deployment_phase.modulate = BM.get_current_slot_color().color
		#IM.get_player_by_index(army.army_reference.controller_index)

		announcement_end_of_deployment_phase.modulate.a = 1
		var tween = ANIM.ui_tween()
		tween.tween_interval(1.5)
		tween.tween_property(announcement_end_of_deployment_phase, "modulate:a", 0, 0.5)
		ANIM.play_tween(tween, ANIM.TweenPlaybackSettings.speed_independent())

#endregion Deployment Phase


#region Grid


## Clears any hovering of grid tiles and units.
func reset_grid_hover() -> void:
	if BM.battle_is_active():
		if _hovered_unit_form_pointer != null:
			# sometimes it's a bugged null which isn't detected with just "if value:"
			# Bug is fixed in Godot 4.4
			_hovered_unit_form_pointer.set_hovered(false)
	if _hovered_tile_form_pointer and is_instance_valid(_hovered_tile_form_pointer):
		_hovered_tile_form_pointer.set_hovered(false)
	_hovered_unit_form_pointer = null
	_hovered_tile_form_pointer = null


## Called when the mouse cursor hovers a tile. It's called similarly to BM's grid_input.
func grid_hover(coord : Vector2i, is_hovered : bool) -> void:
	## This function uses BattleManager's functions to use its grid colliders. The reason for this
	## is to get same result with hover and select when the cursor is at each place.
	reset_grid_hover()

	if BM.battle_is_active():
		var unit_form : UnitForm = BM.get_unit_form(coord)
		if unit_form:
			unit_form.set_hovered(is_hovered)
			_hovered_unit_form_pointer = unit_form if is_hovered else null

		var tile_form : TileForm = BM.get_tile_form(coord)
		if tile_form and tile_form.type != "SENTINEL" and tile_form.type != "":
			tile_form.set_hovered(true)
			_hovered_tile_form_pointer = tile_form


func force_hover_refresh() -> void:
	if not UI.camera:
		return

	# TODO pack to some pretty funcitons
	var space_state := BM.get_world_2d().direct_space_state
	var mouse := BM.get_global_mouse_position()

	# HACK -- get_global_mouse_position() returns different result than when
	# called from BM's _process -- line below is a workaround
	mouse += UI.camera.position - UI.camera.get_screen_center_position()

	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space_state.intersect_point(query, 1)
	if result.size() < 1:
		reset_grid_hover()
		return
	var collider = result[0]["collider"]
	var tile_form = collider as TileForm
	if not tile_form:
		reset_grid_hover()
		return
	grid_hover(tile_form.coord, true)


#endregion Grid


#region Magic

## Upon selecting a unit presents clickable spells that unit posses
func load_spells(army_index : int, spells : Array[BattleSpell], preview : bool = false) -> void:
	selected_spell = null #TODO check if neccesary
	selected_spell_button = null

	if not preview:
		current_player = army_index

	#TODO implement this:
	# Get background color for spell book
	"""var unit_controller : Player = armies_reference[army_index].army_reference.controller
	var bg_color : DataPlayerColor = CFG.NEUTRAL_COLOR
	if unit_controller:
		bg_color = unit_controller.get_player_color()"""


	for spell in spells:
		var button := TextureButton.new()

		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
		button.custom_minimum_size = Vector2(400, 400)
		button.ignore_texture_size = true

		button.texture_normal = CFG.DEPLOY_BUTTON_TEXTURE
		button.texture_normal = load(spell.icon_path)

		button.tooltip_text = spell.description

		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.custom_minimum_size = Vector2(200, 200)

		book.add_child(button)
		var lambda = func on_click():
			if (current_player != army_index):
				return
			if selected_spell_button:  # Deselects previously selected spell
				selected_spell_button.modulate = Color.WHITE

			if selected_spell_button == button: # Selecting the same spell twice deselects it
				selected_spell = null
				selected_spell_button = null
			else:
				selected_spell = spell
				selected_spell_button = button
				selected_spell_button.modulate = Color.RED

			BM.update_move_highlights()
		button.pressed.connect(lambda)


## removes avalaible spells from the list upon desecting a unit
func reset_spells() -> void:
	# clean spells
	for old_buttons in book.get_children():
		old_buttons.queue_free()

#endregion Magic


func start_player_turn(army_index : int):
	on_player_selected(army_index, false)



func refresh_after_undo(deploy_phase_active : bool):
	units_box.visible = deploy_phase_active


func _on_switch_camera_pressed():
	UI.switch_camera()
	if UI.current_camera_position == E.CameraPosition.WORLD:
		camera_button.text = "Show Battle"
	else :
		camera_button.text = "Show World"


func _on_menu_pressed():
	UI.main_menu.open_in_game_menu()


func show_text_bubble(text_bubble : TextBubble) -> void:
	$TextBubble.show()
	$TextBubble/Title.text = text_bubble.title
	$TextBubble/Text.text = text_bubble.text
	$TextBubble/Icon.texture = load(text_bubble.icon_path)
	IM.set_game_paused(true)


func _on_text_bubble_button_pressed():
	IM.set_game_paused(false)
	$TextBubble.hide()
