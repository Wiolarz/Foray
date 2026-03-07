@abstract class_name GameModeSetup
extends Control


var game_setup : GameSetup



var uninitialized : bool = true
var settings_are_being_refreshed : bool = false


var maps_list : OptionButton
var player_list : Container
var client_side_map_label : Label


## assigned either IM.get_battle_maps_list() or IM.get_world_maps_list() on ready
## TODO: and when new map gets added
var maps : Array[String]
var player_slot_panel_scene_path : String
var player_slot_panels : Array[PlayerSlotPanel] = []

@abstract
func _custom_refresh_nodes() -> void

@abstract
func _refresh_slot(index : int) -> void


@abstract
func _on_map_list_item_selected(index : int) -> void


#region Setup

@abstract
func _pre_ready_init() -> void


func _ready_init() -> void:
	assert(maps)
	assert(player_list)
	assert(maps_list)
	assert(player_slot_panel_scene_path)
	Helpers.remove_all_children(player_list) # remove mockup nodes

	UI.resources_list_changed.connect(refresh)
	fill_maps_list()


func _ready() -> void:
	_pre_ready_init()
	_ready_init()


func fill_maps_list():
	assert(not maps.is_empty()) #TODO make sure somewhere, that there are always some accessible maps
	if not maps_list: # Client Side TODO verify its a proper approach
		return
	maps_list.clear()
	for map_name in maps:
		maps_list.add_item(map_name)

	#_on_map_list_item_selected(0) # TODO remember last played map and auto select it

#endregion Setup


## Updates UI to match GameState in IM
func refresh():
	#if settings_are_being_refreshed:
	#	return
	assert(not settings_are_being_refreshed) # todo, write down documenation of how its supposed to be used, or refactor it
	settings_are_being_refreshed = true # destructor or finally whould be nice
	prepare_player_slots()

	update_maps_list_selection()

	for index in range(IM.game_setup_info.slots.size()):
		_refresh_slot(index)

	_custom_refresh_nodes()
	uninitialized = false
	settings_are_being_refreshed = false




#region Selected Map

## in this function we adjust GUI slots number to logical slots number
func prepare_player_slots() -> void:

	var old_ui_slots : Array[Node] = player_list.get_children()

	var logic_slots_count : int = IM.game_setup_info.slots.size()
	var ui_slots_count : int = old_ui_slots.size()

	# go through all slots which are on either side
	var slots_count : int = max(logic_slots_count, ui_slots_count)

	for i in slots_count:
		var ui_slot : PlayerSlotPanel = null

		# if UI slot does not exist, create it and assign to `ui_slot`
		if i >= ui_slots_count:
			ui_slot = load(player_slot_panel_scene_path).instantiate()
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

#endregion Selected Map


#region Resource lists

#TODO verify what here is actually useful
func update_maps_list_selection() -> void:
	if not maps_list:
		assert(client_side_map_label)
		if IM.game_setup_info.world_map:
			client_side_map_label.text = DataWorldMap.get_network_id(IM.game_setup_info.world_map)
		else:
			client_side_map_label.text = DataBattleMap.get_network_id(IM.game_setup_info.battle_map)
		return # on client
	var target : String = IM.game_setup_info.map_name_hint
	if target == "":
		maps_list.select(-1)
		return

	for index in maps_list.item_count:
		var item : String = maps_list.get_item_text(index)
		if target == item:
			maps_list.select(index)
			return



#endregion Resource lists

## It is used to know if changes in gui are made by user and should be passed to
## backend (change setup info and send over network) OR made by refreshing
## gui to state in backend
func should_react_to_changes() -> bool:
	return not settings_are_being_refreshed and not uninitialized


func slot_to_index(slot) -> int:
	return slot.get_index()


func cycle_color_slot(slot : PlayerSlotPanel, backwards : bool) -> bool:
	assert(game_setup)
	var index : int = slot_to_index(slot)
	var changed : bool = game_setup.try_to_cycle_color_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed


func try_to_take_slot(slot) -> bool: # true means something changed
	assert(game_setup)
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_take_slot(index)
	if changed:
		refresh()
	return changed


func try_to_leave_slot(slot) -> bool:
	assert(game_setup)
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_leave_slot(index)
	if changed:
		_refresh_slot(index)
	return changed





