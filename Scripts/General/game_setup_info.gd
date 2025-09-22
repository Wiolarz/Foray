class_name GameSetupInfo
extends RefCounted

## Game Setup in the lobby [br]
## Map chosen, info on game slots setup (races, colors, etc) [br]
## WARNING not a resource because we refer to players, sessions
## and other temporary objects that should not be saved

enum GameMode {
	UNKNOWN, ## forces to initialize
	WORLD, ## full map with heroes and economy
	BATTLE, ## single battle only, no economy
	MAP_EDITOR, ## special mode only for map editing
}

var game_mode : GameMode = GameMode.WORLD
var world_map : DataWorldMap ## used only in full world mode
var battle_map : DataBattleMap ## used only in battle mode
var slots : Array[Slot] ## slot for each player color on the map picked

## used in dropdown list in UI of battle setup, due to the problem with loading selected map
## with a preset not setting selection properly
var battle_preset_name_hint : String

## used in dropdown list in UI of battle setup, due to the problem with loading selected map
## with a preset not setting selection properly
var battle_map_name_hint : String

func is_in_mode_world():
	return game_mode == GameMode.WORLD

func is_in_mode_battle():
	return game_mode == GameMode.BATTLE

func is_bot(player_index : int) -> bool:
	return slots[player_index].is_bot()

func has_slot(player_index : int) -> bool:
	return player_index >= 0 and player_index < slots.size()


func set_team(slot_index : int, team_idx : int):
	slots[slot_index].team = team_idx


## Gameplay setting a unit to memory
func set_unit(slot_index : int, unit_index : int, unit_data : DataUnit):
	slots[slot_index].units_list[unit_index] = unit_data


func set_battle_bot(slot_index : int, path : String):
	slots[slot_index].battle_bot_path = path


## Gameplay setting a hero to memory
func set_hero(slot_index : int, hero_data : DataHero):
	if hero_data:
		slots[slot_index].slot_hero = Hero.construct_hero(hero_data, slot_index)
	else:
		slots[slot_index].slot_hero = null

## Gameplay setting Timer to memory
func set_timer(slot_index : int, reserve_sec : int, increment_sec : int):
	slots[slot_index].timer_reserve_sec = reserve_sec
	slots[slot_index].timer_increment_sec = increment_sec


func to_dictionary(local_username : String = "") -> Dictionary:
	var result = {
		"game_mode": game_mode_to_str(),
		"world_map": DataWorldMap.get_network_id(world_map),
		"battle_map": DataBattleMap.get_network_id(battle_map),
		"slots": [],
	}
	for slot in slots:
		result["slots"].append({
			"occupier": GameSetupInfo.occupier_prepare_for_network( \
					slot.occupier, local_username),
			"race": slot.race.get_network_id(),
			"color": slot.color_idx,
			"units_list": GameSetupInfo.units_list_prepare_for_network( \
					slot.units_list),
			"team": slot.team,
			"timer_reserve": slot.timer_reserve_sec,
			"timer_increment": slot.timer_increment_sec,
		})
	return result


static func from_dictionary(dict : Dictionary, \
		local_username : String = "") -> GameSetupInfo:
	var result = GameSetupInfo.new()
	if "game_mode" in dict and dict["game_mode"] is String:
		result.game_mode = GameSetupInfo.game_mode_from_str(dict["game_mode"])
	if "world_map" in dict and dict["world_map"] is String:
		result.world_map = DataWorldMap.from_network_id(dict["world_map"])
	if "battle_map" in dict and dict["battle_map"] is String:
		result.battle_map = DataBattleMap.from_network_id(dict["battle_map"])
	if "slots" in dict and dict["slots"] is Array:
		for i in dict["slots"].size():
			var read_slot : Dictionary = dict["slots"][i]
			var new_slot : Slot = Slot.new()
			new_slot.index = i
			if "occupier" in read_slot:
				new_slot.occupier = occupier_receive_from_network( \
					read_slot["occupier"], local_username)
			if "race" in read_slot and read_slot["race"] is String:
				new_slot.race = \
					DataRace.from_network_id(read_slot["race"])
			if "color" in read_slot and read_slot["color"] is int:
				new_slot.color_idx = read_slot["color"]
			if "units_list" in read_slot and read_slot["units_list"] is Array:
				new_slot.units_list = \
						GameSetupInfo.units_list_receive_from_network(read_slot["units_list"])
			if "team" in read_slot and read_slot["team"] is int:
				new_slot.team = read_slot["team"]

			if "timer_reserve" in read_slot and read_slot["timer_reserve"] is int:
				new_slot.timer_reserve_sec = int(read_slot["timer_reserve"])
			if "timer_increment" in read_slot and read_slot["timer_increment"] is int:
				new_slot.timer_increment_sec = int(read_slot["timer_increment"])

			result.slots.append(new_slot)
	return result


func game_mode_to_str() -> String:
	return GameMode.keys()[game_mode].to_lower()


static func game_mode_from_str(mode_as_str : String) -> GameMode:
	mode_as_str = mode_as_str.to_lower()
	for mode in GameMode.keys():
		if mode.to_lower() == mode_as_str:
			return GameMode[mode]
	push_error("Unknown game mode: \"%s\"" % mode_as_str)
	return GameMode.UNKNOWN


static func occupier_prepare_for_network(occupier, local_username : String):
	if occupier is String and occupier == "":
		return local_username
	return occupier


static func occupier_receive_from_network(occupier, local_username : String):
	if occupier is String and occupier == local_username:
		return ""
	if occupier is String or occupier is int:
		return occupier
	push_error("invalid occupier received ", occupier)


static func units_list_prepare_for_network(to_serialize: Array[DataUnit]) -> Array[String]:
	var result : Array[String] = []
	for u in to_serialize:
		result.append(DataUnit.get_network_id(u))
	return result


static func units_list_receive_from_network(serialized: Array) -> Array[DataUnit]:
	var result :Array[DataUnit] = []
	for s in serialized:
		result.append(DataUnit.from_network_id(s))
	return result


## also gets optional map name (for UI)
func set_battle_map(map : DataBattleMap, map_name : String = ""):
	assert(game_mode == GameMode.BATTLE, "setting battle map in game mode: " + str(game_mode))
	battle_map = map

	var slots_number = map.player_slots.keys().size()
	set_slots_number(slots_number)

	for slot_idx in slots.size():
		var number_of_unit_slots = map.player_slots[slot_idx + 1] - 1  # -1 space is reserved for hero unit
		slots[slot_idx].set_units_length(number_of_unit_slots)

	battle_map_name_hint = map_name


func set_world_map(map: DataWorldMap):
	assert(game_mode == GameMode.WORLD, "setting world map in game mode: " + str(game_mode))

	world_map = map

	var map_slots_size = 2

	while slots.size() > map_slots_size:
		slots.pop_back()

	var taken_colors = []
	for slot in slots:
		taken_colors.append(slot.color_idx)

	while slots.size() < map_slots_size:
		var slot = Slot.new()
		slots.append(slot)
		var race_idx = wrap(slots.size()-1, 0, CFG.RACES_LIST.size())
		slot.race = CFG.RACES_LIST[race_idx]
		slot.color_idx = 0

		while slot.color_idx in taken_colors:
			slot.color_idx += 1

		taken_colors.append(slot.color_idx)


## used at start with some default preset, also used when preset is chosen
## in UI
## Also, this do not refresh UI and broadcast over network itself -- it should
## be done elsewhere, when this function is called
## preset_name is optional -- only used for auto select at start
func apply_battle_preset( \
	preset : PresetBattle, preset_name : String = "") -> void:
	var map_name : String = preset.battle_map.resource_path.get_file()
	var map_path : String = CFG.BATTLE_MAPS_PATH + "/" + map_name
	assert(ResourceLoader.exists(map_path), "map with name %s does not exist" % map_name)
	var map : DataBattleMap = load(map_path)
	assert(map, "map with name %s is corruped" % map_name)
	set_battle_map(map, map_name)

	# now we need to set armies and teams from preset
	for i in range(slots.size()):
		var slot : Slot = slots[i]
		var army_preset : PresetArmy = preset.armies[i]
		slot.team = army_preset.team
		set_hero(i, army_preset.hero)

		var units := slot.units_list
		for j in units.size():
			var unit : DataUnit = null
			if j < army_preset.units.size():
				unit = army_preset.units[j]
			units[j] = unit

	battle_preset_name_hint = preset_name


static func create_empty() -> GameSetupInfo:
	var slot_count = 2
	var result = GameSetupInfo.new()
	result.slots.resize(slot_count)
	for i in range(slot_count):
		result.slots[i] = Slot.new()
		result.slots[i].race = CFG.RACES_LIST[i]
		result.slots[i].color_idx = i
		result.slots[i].index = i
	return result


func set_slots_number(number : int) -> void:

	# first we remove unused slots
	while slots.size() > number:
		slots.pop_back()

	# check which colors are used to avoid assigning them to new slots
	var taken_colors = []
	for slot in slots:
		taken_colors.append(slot.color_idx)

	# add new slots
	while slots.size() < number:
		var index = slots.size()
		var slot = Slot.new()
		slots.append(slot)

		slot.race = CFG.RACES_LIST[0]
		slot.color_idx = 0
		slot.index = index

		while slot.color_idx in taken_colors:
			slot.color_idx += 1

		taken_colors.append(slot.color_idx)
