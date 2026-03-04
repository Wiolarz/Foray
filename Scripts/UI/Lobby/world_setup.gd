class_name WorldSetup
extends GameModeSetup

# used on client side setup instead of option button
var client_side_map_label : Label

@onready var player_list = \
	$V/Slots/ColorRect/PlayerList


@onready var map_select : VBoxContainer = \
	$V/MapSelect


var player_slot_panels = []


func _ready():
	maps_list = get_node("V/MapSelect/ColorRect/MapList")
	maps = IM.get_world_maps_list()
	rebuild()


func refresh():
	settings_are_being_refreshed = true # destructor or finally whould be nice
	fill_maps_list()
	# drut?
	var world_map = DataWorldMap.get_network_id(IM.game_setup_info.world_map)
	refresh_map_to(world_map)
	for index in range(player_slot_panels.size()):
		_refresh_slot(index)

	uninitialized = false
	settings_are_being_refreshed = false


func refresh_map_to(world_map : String):
	if maps_list:
		for index in maps_list.item_count:
			if world_map == maps_list.get_item_text(index):
				maps_list.selected = index
				return
		maps_list.selected = -1
	if client_side_map_label:
		client_side_map_label.text = world_map


func _refresh_slot(index : int) -> void:
	if not index in range(player_slot_panels.size()):
		return
	var ui_slot : WorldPlayerSlotPanel = player_slot_panels[index]
	ui_slot.setup_ui = self
	var logic_slot : Slot = \
		IM.game_setup_info.slots[index] if index in \
				range(IM.game_setup_info.slots.size()) \
			else null
	var color : DataPlayerColor = CFG.DEFAULT_TEAM_COLOR
	var username : String = ""
	var race : DataRace = CFG.RACES_LIST[0]
	var take_leave_button_state : WorldPlayerSlotPanel.TakeLeaveButtonState =\
		WorldPlayerSlotPanel.TakeLeaveButtonState.GHOST
	#assert(logic_slot)
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
		ui_slot.apply_bots_from_slot(logic_slot)

	ui_slot.set_visible_color(color.color)
	ui_slot.set_visible_name(username)
	ui_slot.set_visible_race(race)
	ui_slot.set_visible_take_leave_button_state(take_leave_button_state)






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
	$V/PresetSelect.queue_free()


func _on_map_list_item_selected(_index : int) -> void:
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
