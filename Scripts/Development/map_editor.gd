extends CanvasLayer


@export var map_file_name_input : TextEdit

@export var new_map_width : int = 5
@export var new_map_height : int = 5


var current_brush : DataTile
var current_button: TextureButton

@onready var tile_buttons_box : BoxContainer = $TopBar/MarginContainer/VBoxContainer/Scroll/TilesPickerBox
@onready var tile_name_label : Label = $TopBar/MarginContainer/VBoxContainer/TileNameContainer/TileNameLabel
@onready var tiles_world : Array[String] = \
		FileSystemHelpers.list_files_in_folder(CFG.WORLD_MAP_TILES_PATH, true)
@onready var tiles_battle : Array[String] = \
		FileSystemHelpers.list_files_in_folder(CFG.BATTLE_MAP_TILES_PATH, true)
@onready var message_label : Label = $InfoLabel

@onready var new_world_button = $Bottom/HBox/NewWorldMap
@onready var new_battle_button = $Bottom/HBox/NewBattleMap

var world_grid : WorldEditGrid

#region Setup

## First function that gets called once editor is launched
func open_draw_menu():
	visible = true
	_mark_button()
	_load_tile_buttons()
	if CFG.MAP_EDITOR_BATTLE:
		_on_new_battle_map_pressed() # TEMP move to seperete function
	else:
		_on_new_world_map_pressed()


func _create_button(map_tile : String) -> TextureButton:
	var tile = load(map_tile)

	var new_button = TextureButton.new()
	new_button.texture_normal = ResourceLoader.load(tile.texture_path)
	new_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	new_button.ignore_texture_size = true
	new_button.custom_minimum_size = Vector2(130,160)

	var lambda = func on_click():
		if current_button != null:
			current_button.modulate = Color.WHITE
		current_brush = tile
		current_button = new_button
		current_button.modulate = Color.DIM_GRAY
		tile_name_label.text = tile.type

	new_button.pressed.connect(lambda)  # self._button_pressed
	return new_button

#endregion Setup


#region Tools

## Called when user presses on the map tile
## Replaces target map tile with currently selected "brush" (map tile type)
func grid_input(coord : Vector2i) -> void:
	if CFG.MAP_EDITOR_BATTLE:
		BM.paint(coord, current_brush)
	else:
		world_grid.paint(coord, current_brush)



func _switch_grid_type() -> void:
	CFG.player_options.map_editor_default_battle = \
	 not CFG.player_options.map_editor_default_battle
	CFG.save_player_options()
	_mark_button()
	# TODO move to function
	_load_tile_buttons()


func _load_tile_buttons():
	var tile_set = tiles_battle if CFG.MAP_EDITOR_BATTLE else tiles_world
	for b in tile_buttons_box.get_children():
		b.queue_free()
	var new_buttons = []
	for tile_path in tile_set:
		new_buttons.append(_create_button(tile_path))
	for b in new_buttons:
		tile_buttons_box.add_child(b)
	# pick first tile as a default tile
	new_buttons[0].pressed.emit()



func _mark_button():
	if CFG.MAP_EDITOR_BATTLE:
		new_battle_button.modulate = Color.FIREBRICK
		new_world_button.modulate = Color.WHITE
	else:
		new_world_button.modulate = Color.FIREBRICK
		new_battle_button.modulate = Color.WHITE

#endregion Tools


#region Saving Map

# TODO should be static, TODO make it detect empty sentinel tiles, to allow background sentinel tiles
func _optimize_grid_size(local_tile_grid : Array) -> Array:
	"""
	checks for the first and last non-sentinel tile placed in each grid row and column.
	Then it will remove all empty columns at map edges
	this function should be called during saving of a scene
	"""
	# # location of the first non sentinel tiles from:
	var left_pos : int = local_tile_grid.size()
	var right_pos : int = 0
	var top_pos : int = local_tile_grid[0].size()
	var bot_pos : int = 0
	var found_any_tiles = false
	for x in local_tile_grid.size():
		for y in local_tile_grid[0].size():
			if local_tile_grid[x][y].type != "SENTINEL":
				found_any_tiles = true
				if left_pos > x:
					left_pos = x
				elif right_pos < x:
					right_pos = x
				if top_pos > y:
					top_pos = y
				if bot_pos < y:
					bot_pos = y
	if not found_any_tiles:
		push_warning("map without any tiles...")
		return [[]]

	for right in range(max(local_tile_grid.size() - right_pos - 1, 0)):
		local_tile_grid.pop_back()

	for left in range(max(left_pos, 0)):
		local_tile_grid.pop_front()

	var rows_at_the_back_to_remove : int = local_tile_grid[0].size() - bot_pos

	for column in local_tile_grid:
		for bot in range(max(rows_at_the_back_to_remove - 1, 0)):
			column.pop_back()

		for top in range(max(top_pos, 0)):
			column.pop_front()

	#print(left_pos, " ", right_pos, " ", top_pos, " ", bot_pos)
	return local_tile_grid


func _generate_world_max_player_number(_local_tile_grid : Array) -> int:
	return 2  # TEMP


func _generate_battle_players_slots(local_tile_grid : Array) -> Dictionary:
	var player_slots : Dictionary = {}
	for tile_column : Array in local_tile_grid:
		for tile : TileForm in tile_column:
			if tile.type.substr(1) == "_player_spawn":
				var player_idx : int = tile.type[0].to_int()
				if player_idx in player_slots.keys():
					player_slots[player_idx] += 1
				else:
					player_slots[player_idx] = 1
	return player_slots

#endregion Saving Map


#region Buttons

func _on_load_map_pressed():
	var map_path = CFG.WORLD_MAPS_PATH
	if CFG.MAP_EDITOR_BATTLE:
		map_path = CFG.BATTLE_MAPS_PATH
	map_path += map_file_name_input.text + ".tres"
	var map_to_load = load(map_path)
	assert(map_to_load != null, "there is no selected map to be loaded")

	WM.clear_world()
	BM.unload_for_editor()

	if map_to_load is DataWorldMap:
		if CFG.MAP_EDITOR_BATTLE:
			_switch_grid_type()
		world_grid.load_map(map_to_load)
	else:
		if not CFG.MAP_EDITOR_BATTLE:
			_switch_grid_type()
		BM.load_editor_map(map_to_load)


func get_battle_map(trim : bool = true) -> DataBattleMap:
	var result = DataBattleMap.new()
	result.grid_data = []

	var manager_grid_data = BM.editor_get_hexes_copy_as_array()
	if trim:
		manager_grid_data = _optimize_grid_size(manager_grid_data)
	for tile_column in manager_grid_data:
		var current_column = []
		for tile : TileForm in tile_column:
			current_column.append( DataTile.create_data_tile(tile))
		result.grid_data.append(current_column)

	result.grid_width = manager_grid_data.size()
	result.grid_height = manager_grid_data[0].size()
	var player_slots =  _generate_battle_players_slots(manager_grid_data)
	# print(player_slots)
	result.player_slots = player_slots
	result.max_player_number = player_slots.keys().size()
	return result


func get_world_map(trim : bool =  true) -> DataWorldMap:
	var map = world_grid.get_current_map(trim)
	return map


func show_info(message : String) -> void:
	message_label.text = message


func _on_save_map_pressed():
	print("saving map")
	var map_file_name : String = map_file_name_input.text
	var new_map
	var save_path
	if CFG.MAP_EDITOR_BATTLE:
		new_map = get_battle_map()
		save_path = CFG.BATTLE_MAPS_PATH + map_file_name + ".tres"
	else:
		new_map = get_world_map(true)
		if not new_map:
			show_info("cannot save map")
			return
		save_path = CFG.WORLD_MAPS_PATH + map_file_name + ".tres"

	ResourceSaver.save(new_map, save_path)
	# WARNING clears uids
	# see https://github.com/godotengine/godot/issues/83259
	# use uid_fixer script to fix

	show_info("map saved")
	UI.resources_list_changed.emit()

	print("end save map")
	# print("reloading map")
	# _on_load_map_pressed()


func _generate_empty_map(size_x : int = 5, size_y : int = 5) -> Array: # -> Array[Array[DataTile]]
	WM.clear_world()
	BM.unload_for_editor()
	var grid_data = []

	for tile_column in range(size_x):
		var current_column = []
		grid_data.append(current_column)
		for tile in range(size_y):
			current_column.append(create_empty_tile())

	return grid_data


func _on_new_world_map_pressed():
	if CFG.MAP_EDITOR_BATTLE:
		_switch_grid_type()
	map_file_name_input.text = "new_world"

	BM.unload_for_editor()
	_drop_world_grid()

	world_grid = WorldEditGrid.new()
	world_grid.resize(Vector2i(5, 5))

	get_parent().add_child(world_grid)
	world_grid.name = "EW_GRID"


func _on_new_battle_map_pressed():
	if not CFG.MAP_EDITOR_BATTLE:
		_switch_grid_type()
	map_file_name_input.text = "new_battleground"

	_drop_world_grid()

	var new_map = DataBattleMap.new()
	var grid_data = _generate_empty_map()
	new_map.grid_data = grid_data

	new_map.grid_height = grid_data.size()
	new_map.grid_width = grid_data[0].size()
	#print(new_map.grid_height, " ", new_map.grid_width)
	BM.unload_for_editor()
	BM.load_editor_map(new_map)


func _drop_world_grid():
	if not world_grid:
		return
	world_grid.get_parent().remove_child(world_grid)
	world_grid.queue_free()
	world_grid = null


func _on_open_button_pressed():
	$FileDialog.root_subfolder = CFG.WORLD_MAPS_PATH \
			if not CFG.MAP_EDITOR_BATTLE else CFG.BATTLE_MAPS_PATH
	$FileDialog.show()


func _on_file_dialog_file_selected(path : String):
	map_file_name_input.text = path.get_file().trim_suffix(".tres")
	_on_load_map_pressed()


func _on_back_button_pressed():
	hide()
	IM.go_to_main_menu()

#endregion Buttons

func create_empty_tile() -> DataTile:
	return load(CFG.SENTINEL_TILE_PATH)


# maybe we should delete this after conflict
func get_tile_grid_data() -> Array:
	if CFG.MAP_EDITOR_BATTLE:
		return BM.tile_grid.hexes
	else:
		return world_grid.get_tile_grid_data()


func _on_add_column_pressed():
	if CFG.MAP_EDITOR_BATTLE:
		var new_map := get_battle_map(false)
		new_map.grid_data.append(create_empty_row(new_map.grid_height))
		new_map.grid_width += 1
		BM.unload_for_editor()
		BM.load_editor_map(new_map)
		UI.set_camera(E.CameraPosition.BATTLE, false)
	else:
		var size = world_grid.size()
		size.x += 1
		world_grid.resize(size)
		UI.set_camera(E.CameraPosition.WORLD, false)


func create_empty_row(length : int) -> Array[DataTile]:
	var row: Array[DataTile] = []
	for x in length:
		row.append(create_empty_tile())
	return row


func _on_add_row_pressed():
	if CFG.MAP_EDITOR_BATTLE:
		var new_map := get_battle_map(false)
		for row in new_map.grid_data:
			row.append(create_empty_tile())
		new_map.grid_height += 1
		BM.unload_for_editor()
		BM.load_editor_map(new_map)
		UI.set_camera(E.CameraPosition.BATTLE, false)
	else:
		var size = world_grid.size()
		size.y += 1
		world_grid.resize(size)
		UI.set_camera(E.CameraPosition.WORLD, false)
