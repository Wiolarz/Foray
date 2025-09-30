# Singleton - UI
extends Node

var main_menu
var ui_overlay
var map_editor
var unit_editor
var tile_editor
var host_lobby
var client_lobby

var camera : PolyCamera
var current_camera_position = E.CameraPosition.WORLD

signal update_settings()
signal resources_list_changed()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	IM.init_game_setup() # drut

	main_menu    = load("res://Scenes/UI/MainMenu.tscn").instantiate()
	ui_overlay   = load("res://Scenes/UI/UIOverlay.tscn").instantiate()
	map_editor   = load("res://Scenes/UI/Editors/MapEditor.tscn").instantiate()
	unit_editor  = load("res://Scenes/UI/Editors/UnitEditor.tscn").instantiate()
	tile_editor  = load("res://Scenes/UI/Editors/TileEditor.tscn").instantiate()

	add_child(main_menu)
	add_child(map_editor)
	add_child(unit_editor)
	add_child(tile_editor)
	add_child(ui_overlay)

	_hide_all()


func add_custom_screen(custom_ui : CanvasLayer):
	add_child(custom_ui)
	custom_ui.hide()
	# we need them always at the top
	if ui_overlay:
		move_child(ui_overlay, -1)


func go_to_custom_ui(custom_ui : CanvasLayer):
	_hide_all()
	custom_ui.show()


func _hide_all():
	for c in get_children(true):
		c.hide()
	BG.set_default_colors()


func go_to_main_menu():
	_hide_all()
	main_menu.open_main_menu()
	DISCORD.change_state("Sitting in main menu")


func go_to_unit_editor():
	_hide_all()
	unit_editor.show()
	AUDIO.play_music("battle_drums")


func go_to_tile_editor():
	_hide_all()
	tile_editor.show()
	AUDIO.play_music("battle_drums")


## TEMP
func go_to_map_editor():
	_hide_all()
	map_editor.open_draw_menu()
	AUDIO.play_music("battle_drums")
	BG.set_player_colors(CFG.NEUTRAL_COLOR)


#region Input Support

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("KEY_EXIT_GAME"):
		IM.quit_game()
	if Input.is_action_just_pressed("KEY_MAXIMIZE_WINDOW"):
		toggle_fullscreen()

	if Input.is_action_just_pressed("KEY_MENU"):
		main_menu.open_in_game_menu()
	if Input.is_action_just_pressed("KEY_DEBUG_COLLISION_SHAPES"):
		toggle_collision_debug()
	if event.is_action_pressed("KEY_BOT_SPEED_SLOW"):
		print("anim speed - slow")
		CFG.animation_speed_frames = CFG.AnimationSpeed.NORMAL
		CFG.bot_speed_frames = CFG.BotSpeed.FREEZE
	elif event.is_action_pressed("KEY_BOT_SPEED_MEDIUM"):
		print("anim speed - medium")
		CFG.animation_speed_frames = CFG.AnimationSpeed.NORMAL
		CFG.bot_speed_frames = CFG.BotSpeed.NORMAL
	elif event.is_action_pressed("KEY_BOT_SPEED_FAST"):
		print("anim speed - fast")
		CFG.animation_speed_frames = CFG.AnimationSpeed.INSTANT
		CFG.bot_speed_frames = CFG.BotSpeed.FAST
	elif Input.is_action_just_pressed("KEY_FORCE_DESYNC"):
		print("forcing desynchronization")
		NET.desync()
	if camera and not get_tree().paused:
		camera.process_input_event(event)


	if event.is_action_pressed("UNDO"):
		BM.undo()
	elif event.is_action_pressed("REDO"):
		BM.redo()
	elif event.is_action_pressed("AI_MOVE"):
		BM.ai_move()

	# if event.is_action_pressed("KEY_SAVE_GAME"):
	# 	print("quick save is not yet supported")

	# if event.is_action_pressed("KEY_LOAD_GAME"):
	# 	print("quick load is not yet supported")


# called from TileForm mouse detection
func grid_input_listener(tile_coord : Vector2i, \
		tile_type : GameSetupInfo.GameMode, mouse_drag : bool):
	#print("tile ", tile_coord)
	if IM.in_map_editor:
		if mouse_drag:
			map_editor.grid_input(tile_coord)
		return

	if mouse_drag:
		return

	if tile_type == GameSetupInfo.GameMode.BATTLE:
		BM.grid_input(tile_coord)
	elif tile_type == GameSetupInfo.GameMode.WORLD:
		WM.grid_input(tile_coord)


# called from TileForm mouse detection
func grid_planning_input_listener(tile_coord : Vector2i, \
		tile_type : GameSetupInfo.GameMode,
		is_it_pressed : bool):
	#print("tile ", tile_coord)

	if tile_type == GameSetupInfo.GameMode.WORLD and is_it_pressed:
		# basic right click has different purpose in World Map
		#TODO classic drawing could be reanabled with addition of holding alt
		WM.show_army_units(tile_coord)
		return

	BM.planning_input(tile_coord, is_it_pressed)

#endregion Input Support

#region Camera

func _process(delta):
	# we do not want to process camera when game is paused
	if camera and not get_tree().paused:
		camera.process_camera(delta)


func ensure_camera_is_spawned() -> void:
	if not camera:
		camera = PolyCamera.new()
		camera.name = "PolyCamera"
		add_child(camera)


func switch_camera() -> void:
	if current_camera_position == E.CameraPosition.WORLD:
		if BM.can_show_battla_camera():
			set_camera(E.CameraPosition.BATTLE)
	else:
		if IM.game_setup_info.game_mode == GameSetupInfo.GameMode.WORLD:
			set_camera(E.CameraPosition.WORLD)


func set_camera(pos : E.CameraPosition, reset_position : bool = true) -> void:
	current_camera_position = pos
	if pos == E.CameraPosition.BATTLE:
		camera.set_bounds(BM.get_bounds_global_position(), reset_position)
	else :
		camera.set_bounds(WM.get_bounds_global_position(), reset_position)

#endregion Camera


#region Fullscreen

## NOTE: fullscreen uses old style exclusive fullscreen because of Godot bug
func set_fullscreen(fullscreen: bool):
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		# DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# TODO: change to borderless when Godot bug is fixed
		# https://github.com/godotengine/godot/issues/63500
		# there is a grey border around the screen
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func toggle_fullscreen():
	# automatically launches set_fullscreen
	CFG.player_options.fullscreen = not CFG.player_options.fullscreen
	CFG.save_player_options()
	update_settings.emit()

#endregion Fullscreen


#region Debug Tools

## Toggle of default godot Debug tool - visible collision shapes
func toggle_collision_debug():

	var tree := get_tree()
	tree.debug_collisions_hint = not tree.debug_collisions_hint

	# Traverse tree to call queue_redraw on instances of
	# CollisionShape2D and CollisionPolygon2D.
	var node_stack: Array[Node] = [tree.get_root()]
	while not node_stack.is_empty():
		var node: Node = node_stack.pop_back()
		if is_instance_valid(node):
			if node is CollisionShape2D or node is CollisionPolygon2D:
				node.queue_redraw()
			if node is TileMap:
				node.collision_visibility_mode = TileMap.VISIBILITY_MODE_FORCE_HIDE
				node.collision_visibility_mode = TileMap.VISIBILITY_MODE_DEFAULT
			node_stack.append_array(node.get_children())

#endregion Debug Tools
