class_name WorldSetup
extends Control

var game_setup : GameSetup

var player_slot_panels = []

# used on client side setup instead of option button
var client_side_map_label : Label

@onready var player_list = \
	$V/Slots/ColorRect/PlayerList

@onready var maps_list : OptionButton = \
	$V/MapSelect/ColorRect/MapList

@onready var map_select : VBoxContainer = \
	$V/MapSelect


func _ready():
	rebuild()
	# fill_maps_list()


func refresh():
	fill_maps_list()
	# drut?
	var world_map = DataWorldMap.get_network_id(IM.game_setup_info.world_map)
	refresh_map_to(world_map)
	for index in range(player_slot_panels.size()):
		_refresh_slot(index)


func refresh_map_to(world_map : String):
	if maps_list:
		for index in maps_list.item_count:
			if world_map == maps_list.get_item_text(index):
				maps_list.selected = index
				return
		maps_list.selected = -1
	if client_side_map_label:
		client_side_map_label.text = world_map


func _refresh_slot(index : int):
	if not index in range(player_slot_panels.size()):
		return
	var ui_slot : WorldPlayerSlotPanel = player_slot_panels[index]
	var logic_slot : Slot = \
		IM.game_setup_info.slots[index] if index in \
				range(IM.game_setup_info.slots.size()) \
			else null
	var color : DataPlayerColor = CFG.DEFAULT_TEAM_COLOR
	var username : String = ""
	var race : DataRace = null
	var take_leave_button_state : WorldPlayerSlotPanel.TakeLeaveButtonState =\
		WorldPlayerSlotPanel.TakeLeaveButtonState.GHOST
	if logic_slot:
		if logic_slot.occupier is String:
			if logic_slot.occupier == "":
				username = NET.get_current_login()
				take_leave_button_state = \
					WorldPlayerSlotPanel.TakeLeaveButtonState.TAKEN_BY_YOU
			else:
				username = logic_slot.occupier
				take_leave_button_state = \
					WorldPlayerSlotPanel.TakeLeaveButtonState.TAKEN_BY_OTHER
		else:
			username = "Computer\nlevel %d" % logic_slot.occupier
			take_leave_button_state = \
				WorldPlayerSlotPanel.TakeLeaveButtonState.FREE
		race = logic_slot.race
		color = CFG.get_team_color_at(logic_slot.color_idx)
	ui_slot.set_visible_color(color.color)
	ui_slot.set_visible_name(username)
	ui_slot.set_visible_race(race)
	ui_slot.set_visible_take_leave_button_state(take_leave_button_state)
	ui_slot.setup_ui = self


func slot_to_index(slot) -> int:
	return player_slot_panels.find(slot)


func try_to_take_slot(slot) -> bool: # true means something changed
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_take_slot(index)
	if changed:
		refresh()
	return changed


func try_to_leave_slot(slot) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_leave_slot(index)
	if changed:
		_refresh_slot(index)
	return changed


func cycle_color_slot(slot : WorldPlayerSlotPanel, backwards : bool) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_cycle_color_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed


func cycle_race_slot(slot : WorldPlayerSlotPanel, backwards : bool) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_cycle_race_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed


func rebuild():
	player_slot_panels = []
	for slot in player_list.get_children():
		player_slot_panels.append(slot)
	# don't want to refresh here -- we want to be able to build this widget
	# without real data


func make_client_side():
	map_select.get_node("Label").text = "Selected map"
	maps_list.queue_free()
	maps_list = null
	client_side_map_label = Label.new()
	client_side_map_label.text = "some map"
	map_select.get_node("ColorRect").add_child(client_side_map_label)
	var presets = $V/PresetSelect
	presets.queue_free()

func fill_maps_list():
	if not maps_list:
		return
	var maps = IM.get_world_maps_list()
	maps_list.clear()
	for map_name in maps:
		maps_list.add_item(map_name)
	if not maps.is_empty():
		_on_map_list_item_selected(0) # kind of drut


func _on_map_list_item_selected(_index):
	if not maps_list:
		return
	if not game_setup:
		print("warning: no game setup")
		return
	var map_name = maps_list.get_item_text(maps_list.selected)
	# drut
	var changed = game_setup.try_to_set_world_map_name(map_name)
	# if changed:
	# 	refresh()
	print("map select %s %s" % [ map_name, changed ])
