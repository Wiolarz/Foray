class_name BattleSetup
extends GameModeSetup


@onready var preset_select : Container = $VBox/PresetSelect
@onready var slots : Container = $VBox/Slots

@onready var presets_list : OptionButton = \
	preset_select.get_node("ColorRect/PresetList")

@onready var hero_level_up_container : VBoxContainer = $VBoxLevelUp
@onready var hero_level_up : Control = $VBoxLevelUp/LevelUpLobbyScreen
@onready var main_container : VBoxContainer = $VBox


#region Initial Setup

func _pre_ready_init() -> void:
	player_slot_panel_scene_path = "res://Scenes/UI/Lobby/BattlePlayerSlotPanel.tscn"
	player_list = slots.get_node("ColorRect/PlayerList")
	map_select = get_node("VBox/MapSelect")
	maps_list = map_select.get_node("ColorRect/MapList")
	maps = IM.get_battle_maps_list()
	fill_presets_list()

	hero_level_up.confirm_button.connect(_on_level_up_confirm_button_pressed)


func fill_presets_list() -> void:
	var presets = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_PRESETS_PATH, true, true)
	presets_list.clear()
	for preset in presets:
		presets_list.add_item(preset.trim_prefix(CFG.BATTLE_PRESETS_PATH))


func update_presets_list_selection() -> void:
	if not presets_list:
		return # on client
	var target : String = IM.game_setup_info.battle_preset_name_hint
	if target != "":
		for i in presets_list.item_count:
			var item : String = presets_list.get_item_text(i)
			if target == item:
				presets_list.select(i)
				return
	presets_list.select(-1)

#endregion Initial Setup


func make_client_side() -> void:
	super()
	preset_select.queue_free()


func _custom_refresh_nodes() -> void:
	update_presets_list_selection()


func _custom_refresh_slot(index : int) -> void:
	var ui_slot : PlayerSlotPanel = player_list.get_child(index)
	var logic_slot : Slot = \
		IM.game_setup_info.slots[index] if IM.game_setup_info.has_slot(index) \
			else null

	ui_slot.set_army(logic_slot.units_list)
	if logic_slot.slot_hero:
		ui_slot.set_hero_option_button(logic_slot.slot_hero.template)
	else:
		ui_slot.set_hero_option_button(null)


#region Changing settings

## add missing path and calls apply_preset()
func _on_preset_list_item_selected(index : int) -> void:
	if not should_react_to_changes():
		return
	select_preset_by_index(index)


func select_preset_by_index(index : int):
	var preset_file = presets_list.get_item_text(index)
	apply_preset_by_name(preset_file)
	refresh()

	CFG.player_options.last_used_battle_preset_name = preset_file
	CFG.save_player_options()


## returns true on successful load and false otherwise
func apply_preset_by_name(preset_name : String) -> bool:

	var preset_data : PresetBattle = \
			load(CFG.BATTLE_PRESETS_PATH + "/" + preset_name) as PresetBattle

	if not preset_data:
		return false

	# TODO check map is good

	IM.game_setup_info.apply_battle_preset(preset_data, preset_name)

	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)
	refresh() # TODO look into those refreshes
	return true


func _load_map(map_name : String) -> void:
	var map : DataBattleMap = load(CFG.BATTLE_MAPS_PATH + "/" + map_name)
	IM.game_setup_info.set_battle_map(map, map_name)


func show_hero_level_up(slot_index : int) -> void:
	var slot : Slot = IM.game_setup_info.slots[slot_index]
	hero_level_up.load_lobby_level_up_screen(slot.slot_hero)
	hero_level_up_container.show()
	main_container.hide()


func hide_hero_level_up() -> void:
	hero_level_up_container.hide()
	main_container.show()


func _on_level_up_confirm_button_pressed():
	hero_level_up.selected_hero.passive_effects.clear()
	hero_level_up.apply_talents_and_abilities()
	hide_hero_level_up()

#endregion Changing settings
