class_name BattleSetup
extends GameModeSetup




@onready var preset_select : Container = $VBox/PresetSelect
@onready var map_select : Container = $VBox/MapSelect
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


## Called upon join, applies changes to the UI to make it Client UI not Host UI
func make_client_side() -> void:
	map_select.get_node("Label").text = "Selected map"
	maps_list.queue_free()
	maps_list = null
	UI.resources_list_changed.disconnect(refresh)  #TODO look into compatibility with multiplayer of resource list changes
	client_side_map_label = Label.new()
	client_side_map_label.text = "some map"
	map_select.get_node("ColorRect").add_child(client_side_map_label)
	preset_select.queue_free()

#endregion Initial Setup


func _custom_refresh_nodes() -> void:
	update_presets_list_selection()


## Updates BattlePlayerSlotPanel to match GameState in IM
func _refresh_slot(index : int) -> void:
	var ui_slot : BattlePlayerSlotPanel = player_list.get_child(index)
	ui_slot.setup_ui = self

	var logic_slot : Slot = \
		IM.game_setup_info.slots[index] if IM.game_setup_info.has_slot(index) \
			else null
	var color : DataPlayerColor = CFG.DEFAULT_TEAM_COLOR
	var username : String = ""
	var race : DataRace = null
	var take_leave_button_state : BattlePlayerSlotPanel.TakeLeaveButtonState =\
		BattlePlayerSlotPanel.TakeLeaveButtonState.GHOST
	var reserve_seconds : int = 0
	var increment_seconds : int = 0
	var team : int = 0



	if logic_slot:
		ui_slot.set_army(logic_slot.units_list)
		if logic_slot.slot_hero:
			ui_slot.set_hero_option_button(logic_slot.slot_hero.template)
		else:
			ui_slot.set_hero_option_button(null)
		if logic_slot.occupier is String:
			if logic_slot.occupier == "":
				username = NET.get_current_login()
				take_leave_button_state = \
					BattlePlayerSlotPanel.TakeLeaveButtonState.TAKEN_BY_YOU
			else:
				username = logic_slot.occupier
				take_leave_button_state = \
					BattlePlayerSlotPanel.TakeLeaveButtonState.TAKEN_BY_OTHER
		else:
			username = "Computer\nlevel %d" % logic_slot.occupier
			take_leave_button_state = \
				BattlePlayerSlotPanel.TakeLeaveButtonState.FREE
		race = logic_slot.race
		color = CFG.get_team_color_at(logic_slot.color_idx)
		team = logic_slot.team
		reserve_seconds = logic_slot.timer_reserve_sec
		increment_seconds = logic_slot.timer_increment_sec

		ui_slot.apply_bots_from_slot(logic_slot)



	ui_slot.set_visible_color(color.color)
	ui_slot.set_visible_name(username)
	ui_slot.set_visible_team(team)
	ui_slot.set_visible_take_leave_button_state(take_leave_button_state)
	ui_slot.set_visible_timers(reserve_seconds, increment_seconds)





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

	# TODO - verify if its neccesary to imrpove on this simple solution
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


func _on_map_list_item_selected(index : int) -> void:
	if not should_react_to_changes():
		return
	var map_name : String = maps_list.get_item_text(index)
	var map : DataBattleMap = load(CFG.BATTLE_MAPS_PATH + "/" + map_name)
	IM.game_setup_info.set_battle_map(map, map_name)

	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)

	refresh()





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
