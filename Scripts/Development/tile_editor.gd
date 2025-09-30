extends ResourceEditor


## override -> applies DataTile type to edited Resource
func _init_resource_type() -> void:
	dirty_changes = DataTile.new()
	set_game_mode()


## override
func apply_texture_to_preview() -> void:
	resource_preview_form.paint(dirty_changes)


## checks CFG.TILE_EDITOR_BATTLE then enters the selected directory
func set_game_mode() -> void:
	if CFG.TILE_EDITOR_BATTLE:
		$HBoxContainer/Edition/VBoxContainer/Top/HBox/SwitchMode.text = "World Tiles"
		resource_directory_path = CFG.WORLD_MAP_TILES_PATH
	else:
		$HBoxContainer/Edition/VBoxContainer/Top/HBox/SwitchMode.text = "Battle Tiles"
		resource_directory_path = CFG.BATTLE_MAP_TILES_PATH
	_load_resources()
	_select_first_item()


func _on_switch_mode_pressed():
	CFG.player_options.tile_editor_default_battle = not CFG.player_options.tile_editor_default_battle
	CFG.save_player_options()
	set_game_mode()
