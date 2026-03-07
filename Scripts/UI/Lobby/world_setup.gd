class_name WorldSetup
extends GameModeSetup


@onready var map_select : VBoxContainer = \
	$V/MapSelect


func _pre_ready_init():
	player_slot_panel_scene_path = "res://Scenes/UI/Lobby/WorldPlayerSlotPanel.tscn"
	player_list = get_node("V/Slots/ColorRect/PlayerList")
	maps_list = get_node("V/MapSelect/ColorRect/MapList")
	maps = IM.get_world_maps_list()


func _custom_refresh_nodes() -> void:
	pass


func _custom_refresh_slot(index : int) -> void:
	var ui_slot : WorldPlayerSlotPanel = player_list.get_child(index)
	ui_slot.setup_ui = self

	var logic_slot : Slot = \
		IM.game_setup_info.slots[index] if index in \
				range(IM.game_setup_info.slots.size()) \
			else null

	if logic_slot.race_lock:
		ui_slot.init_race_button(logic_slot.race)
	else:
		ui_slot.init_race_button()


func make_client_side():
	map_select.get_node("Label").text = "Selected map"
	maps_list.queue_free()
	maps_list = null
	client_side_map_label = Label.new()
	client_side_map_label.text = "some map"
	map_select.get_node("ColorRect").add_child(client_side_map_label)
	$V/PresetSelect.queue_free()


func _load_map(map_name : String) -> void:
	game_setup.try_to_set_world_map_name(map_name)
