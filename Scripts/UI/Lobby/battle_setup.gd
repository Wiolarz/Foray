class_name BattleSetup
extends Control

const PLAYER_SLOT_PANEL_PATH = "res://Scenes/UI/Lobby/BattlePlayerSlotPanel.tscn"

var game_setup : GameSetup

var client_side_map_label : Label

@onready var preset_select : Container = $VBox/PresetSelect
@onready var map_select : Container = $VBox/MapSelect
@onready var slots : Container = $VBox/Slots

@onready var player_list : Container = slots.get_node("ColorRect/PlayerList")
@onready var maps_list : OptionButton = map_select.get_node("ColorRect/MapList")
@onready var presets_list : OptionButton = \
	preset_select.get_node("ColorRect/PresetList")

@onready var hero_level_up_container : VBoxContainer = $VBoxLevelUp
@onready var hero_level_up : Control = $VBoxLevelUp/LevelUpLobbyScreen
@onready var main_container : VBoxContainer = $VBox

var uninitialized : bool = true
var settings_are_being_refreshed : bool = false

#region Initial Setup

func _ready():
	fill_maps_list()
	fill_presets_list()
	UI.resources_list_changed.connect(refresh_after_resource_list_changed)


## It is used to know if changes in gui are made by user and should be passed to
## backend (change setup info and send over network) OR made by refreshing
## gui to state in backend
func should_react_to_changes() -> bool:
	return not settings_are_being_refreshed and not uninitialized


func refresh_after_resource_list_changed() -> void:
	fill_maps_list()
	for slot : BattlePlayerSlotPanel in player_list.get_children():
		slot.load_unit_buttons()
	apply_preset_by_name(CFG.LAST_USED_BATTLE_PRESET_NAME)


func fill_maps_list() -> void:
	var maps = IM.get_battle_maps_list()
	maps_list.clear()
	for map_name in maps:
		maps_list.add_item(map_name)


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


func update_maps_list_selection() -> void:
	if not maps_list:
		return # on client
	var target : String = IM.game_setup_info.battle_map_name_hint
	if target != "":
		for i in maps_list.item_count:
			var item : String = maps_list.get_item_text(i)
			if target == item:
				maps_list.select(i)
				return
	maps_list.select(-1)


## Called upon join, applies changes to the UI to make it Client UI not Host UI
func make_client_side() -> void:
	map_select.get_node("Label").text = "Selected map"
	maps_list.queue_free()
	maps_list = null
	UI.resources_list_changed.disconnect(refresh_after_resource_list_changed)  #TODO look into compatibility with multiplayer of resource list changes
	client_side_map_label = Label.new()
	client_side_map_label.text = "some map"
	map_select.get_node("ColorRect").add_child(client_side_map_label)
	var presets = preset_select
	presets.queue_free()

#endregion


## Updates UI to match GameState in IM
func refresh() -> void:
	assert(not settings_are_being_refreshed)
	settings_are_being_refreshed = true # destructor or finally whould be nice

	prepare_player_slots()

	update_presets_list_selection()
	update_maps_list_selection()

	for index in player_list.get_child_count():
		_refresh_slot(index)

	if client_side_map_label:
		var map_name = \
			DataBattleMap.get_network_id(IM.game_setup_info.battle_map)
		client_side_map_label.text = map_name

	uninitialized = false
	settings_are_being_refreshed = false


## Updates BattlePlayerSlotPanel to match GameState in IM
func _refresh_slot(index : int) -> void:
	if index < 0 or index >= player_list.get_child_count():
		push_error("no ui slot to refresh on index ", index)
		return
	var ui_slot : BattlePlayerSlotPanel = player_list.get_child(index)
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
	ui_slot.set_visible_color(color.color)
	ui_slot.set_visible_name(username)
	ui_slot.set_visible_team(team)
	ui_slot.set_visible_take_leave_button_state(take_leave_button_state)
	ui_slot.set_visible_timers(reserve_seconds, increment_seconds)
	ui_slot.setup_ui = self
	ui_slot.set_bot(logic_slot.battle_bot_path)


func slot_to_index(slot : BattlePlayerSlotPanel) -> int:
	return slot.get_index()


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


func _on_map_list_item_selected(index):
	if not should_react_to_changes():
		return
	var map_name : String = maps_list.get_item_text(index)
	var map : DataBattleMap = load(CFG.BATTLE_MAPS_PATH + "/" + map_name)
	IM.game_setup_info.set_battle_map(map, map_name)

	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)

	refresh()


## in this function we adjust GUI slots number to logical slots number
func prepare_player_slots() -> void:

	var old_ui_slots = player_list.get_children()

	var logic_slots_count : int = IM.game_setup_info.slots.size()
	var ui_slots_count : int = old_ui_slots.size()

	# go through all slots which are on either side
	var slots_count = max(logic_slots_count, ui_slots_count)

	for i in slots_count:
		var ui_slot : BattlePlayerSlotPanel = null

		# if UI slot does not exist, create it and assign to `ui_slot`
		if i >= ui_slots_count:
			ui_slot = load(PLAYER_SLOT_PANEL_PATH).instantiate()
			ui_slot.setup_ui = self
			player_list.add_child(ui_slot)
		else:
			# we didn't assign `ui_slot`, so use existing UI slot
			ui_slot = old_ui_slots[i]

		# UI slot is not needed
		if i >= logic_slots_count:
			player_list.remove_child(ui_slot)
			ui_slot.queue_free()
		else:
			ui_slot.init_team_list(logic_slots_count)


func try_to_take_slot(slot) -> bool: # true means something changed
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_take_slot(index)
	if changed:
		_refresh_slot(index)
	return changed


func try_to_leave_slot(slot) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_leave_slot(index)
	if changed:
		_refresh_slot(index)
	return changed


func cycle_color_slot(slot : BattlePlayerSlotPanel, backwards : bool) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_cycle_color_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed


func cycle_race_slot(slot : BattlePlayerSlotPanel, backwards : bool) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_cycle_race_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed


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

#endregion
