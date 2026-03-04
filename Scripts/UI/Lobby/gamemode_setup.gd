@abstract class_name GameModeSetup
extends Control


var game_setup : GameSetup

#TODO verify if those variables will ever be used
var uninitialized : bool = true
var settings_are_being_refreshed : bool = false


var maps_list : OptionButton

## assigned either IM.get_battle_maps_list() or IM.get_world_maps_list() on ready
## TODO: and when new map gets added
var maps : Array[String]


@abstract
func refresh() -> void


@abstract
func _refresh_slot(index : int) -> void


@abstract
func _on_map_list_item_selected(index : int) -> void


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


func fill_maps_list():
	assert(not maps.is_empty()) #TODO make sure somewhere, that there are always some accessible maps
	if not maps_list: # Client Side TODO verify its a proper approach
		return
	maps_list.clear()
	for map_name in maps:
		maps_list.add_item(map_name)

	_on_map_list_item_selected(0) # TODO remember last played map and auto select it
