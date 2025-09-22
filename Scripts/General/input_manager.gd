# Singleton - IM
# rename to GameManager
extends Node


## notifies when `game_setup_info` is modified
signal game_setup_info_changed

var game_setup_info : GameSetupInfo

var players : Array[Player] = []

## flag for MAP EDITOR
var in_map_editor : bool = false

## flag for City Defense game mode
var is_city_defense_active : bool = false


func init_game_setup():
	game_setup_info = GameSetupInfo.create_empty()


## called:
## * by UI when button is clicked or game starts (host is true)
## * by client when server orders, then host is false
func init_battle_mode(host : bool):
	game_setup_info.game_mode = GameSetupInfo.GameMode.BATTLE

	if host:
		var preset : Dictionary = get_default_or_last_battle_preset()
		game_setup_info.apply_battle_preset(preset["data"], preset["name"])

#region Game setup

func get_world_maps_list() -> Array[String]:
	return FileSystemHelpers.list_files_in_folder(CFG.WORLD_MAPS_PATH)


func get_battle_maps_list() -> Array[String]:
	return FileSystemHelpers.list_files_in_folder(CFG.BATTLE_MAPS_PATH)


func _prepare_to_start_game() -> void:
	_clear_players()

	# Assigning unique team id's to player's without a team
	# To avoid players without a team being treated as allies
	# assigning players without a team
	var occupied_team_slots : Array[int] = []
	for slot in game_setup_info.slots: # assigning NO team players
		if slot.team == 0:
			continue
		elif slot.team not in occupied_team_slots:
			occupied_team_slots.append(slot.team)

	var new_team_idx = 1
	for slot in game_setup_info.slots:
		if slot.team == 0:
			while new_team_idx in occupied_team_slots:
				new_team_idx += 1
			slot.team = new_team_idx
			new_team_idx += 1


	for slot in game_setup_info.slots:
		var player := Player.create(slot)
		players.append(player)
		add_child(player)

	UI.ensure_camera_is_spawned()

	WM.clear_world()
	BM.close_when_quitting_game()
	UI.go_to_main_menu()


## Starts a game in some state based on provided states and on game_setup_info.
## [br]
## If both states are null, then game is started as new and no state load is
## performed -- only game_setup_info is taken into account.
func start_game(world_state : SerializableWorldState = null,
		battle_state : SerializableBattleState = null,
		replay_template : BattleReplay = null) -> void:

	assert(not battle_state or battle_state.valid())
	assert(not world_state or world_state.valid())

	_prepare_to_start_game()
	if game_setup_info.is_in_mode_battle():
		# in battle mode we can only have battle state
		assert(not world_state)

		_start_game_battle(battle_state, replay_template)
		UI.set_camera(E.CameraPosition.BATTLE)
		DISCORD.change_state("Playing custom battle")

	elif game_setup_info.is_in_mode_world():
		# in world mode we can have no states, only world state or both states

		assert((not battle_state and not world_state) or
			(world_state))

		_start_game_world(world_state)
		UI.set_camera(E.CameraPosition.WORLD)
		if battle_state:
			var armies : Array[Army] = []
			for army_coord in battle_state.world_armies:
				armies.append(WS.get_army_at(army_coord))
			WM.start_combat(armies, battle_state.combat_coord, battle_state)
		DISCORD.change_state("Exploring the world map")

	if NET.server:
		NET.server.broadcast_start_game()


func perform_replay(path):
	var replay = load(path) as BattleReplay
	assert(replay != null)

	game_setup_info.game_mode = GameSetupInfo.GameMode.BATTLE
	game_setup_info.battle_map = replay.battle_map

	# Temporarily move slots from game setup
	var old_info = game_setup_info
	game_setup_info = GameSetupInfo.create_empty()
	game_setup_info.game_mode = GameSetupInfo.GameMode.BATTLE
	game_setup_info.set_battle_map(replay.battle_map)
	game_setup_info.set_slots_number(replay.units_at_start.size())

	for slot_id in range(replay.units_at_start.size()):
		var slot = game_setup_info.slots[slot_id]
		var units_array = replay.units_at_start[slot_id]
		slot.occupier = replay.get_player_name(slot_id)
		slot.color_idx = replay.get_player_color(slot_id)
		slot.timer_reserve_sec = replay.player_initial_timers_ms[slot_id] / 1000
		slot.timer_increment_sec = replay.player_increments_ms[slot_id] / 1000
		slot.set_units(units_array)

	start_game(null, null, replay)
	BM.perform_replay(replay)

	# Setup done, move back old info
	game_setup_info = old_info


func go_to_map_editor():
	UI.ensure_camera_is_spawned()
	in_map_editor = true
	UI.go_to_map_editor()


## Full game - World game mode
## new game <=> world_state == null
func _start_game_world(world_state : SerializableWorldState = null):
	UI.go_to_main_menu()
	var map : DataWorldMap = game_setup_info.world_map

	if CFG.FULLSCREEN_AUTO_TOGGLE:
		UI.set_fullscreen(true)

	if not world_state:
		WM.start_new_world(map)
	else:
		WM.start_world_in_state(map, world_state)


## Single Battle - game mode
## new game <=> battle_state == null
func _start_game_battle(battle_state : SerializableBattleState = null,
		replay_template : BattleReplay = null):
	var map_data = game_setup_info.battle_map
	var armies : Array[Army]  = []

	for slot in game_setup_info.slots:
		armies.append(create_army_for(slot))

	UI.go_to_main_menu()

	if CFG.FULLSCREEN_AUTO_TOGGLE:
		UI.set_fullscreen(true)

	var x_offset = 0.0  # no world map to offset from
	BM.start_battle(armies, map_data, x_offset, battle_state, replay_template)


## Creates army based on player slot data
func create_army_for(slot : Slot) -> Army:
	var army = Army.new()
	army.controller_index = slot.index

	army.hero = slot.slot_hero

	army.units_data = slot.get_units_list()

	#TEMP
	army.timer_reserve_sec = slot.timer_reserve_sec
	army.timer_increment_sec = slot.timer_increment_sec

	return army


## Creates army based on army_preset and assigns controller
func create_army_from_preset(army_preset : PresetArmy, player_index : int) -> Army:
	var army = Army.new()
	army.controller_index = player_index

	var hero_data : DataHero = army_preset.hero
	if hero_data:
		var new_hero = Hero.construct_hero(hero_data, player_index)
		army.hero = new_hero

	army.units_data = army_preset.units

	return army


func get_default_or_last_battle_preset() -> Dictionary:
	var last_preset_name : String = CFG.LAST_USED_BATTLE_PRESET_NAME
	var last_preset_path : String = CFG.BATTLE_PRESETS_PATH + "/" + last_preset_name
	var last_preset_data : PresetBattle
	if ResourceLoader.exists(last_preset_path):
		last_preset_data = load(last_preset_path) as PresetBattle
	if last_preset_data:
		return { "data": last_preset_data, "name": last_preset_name }
	var presets = FileSystemHelpers.list_files_in_folder(
		CFG.BATTLE_PRESETS_PATH,
		true,
		true
	)
	assert(presets.size() > 0)
	var preset : PresetBattle = load(presets[0])
	assert(preset is PresetBattle)
	return {
		"data": preset,
		"name": presets[0].trim_prefix(CFG.BATTLE_PRESETS_PATH)
	}


func start_scripted_battle(scripted_battle : ScriptedBattle, battle_bot_path : String = "",
							player_controlled_side : int = 0) -> void:
	print("started scripted battle: ", scripted_battle.scenario_name)

	_prepare_to_start_game()

	var armies : Array[Army]  = []
	_clear_players()

	var player_idx : int = -1
	for army_preset in scripted_battle.armies:
		player_idx += 1
		var new_controller : Player
		if player_controlled_side == player_idx:
			new_controller = Player.create_for_tutorial(player_idx)
		else:
			new_controller = Player.create_for_tutorial(player_idx, battle_bot_path)


		players.append(new_controller)
		add_child(new_controller)

		armies.append(create_army_from_preset(army_preset, player_idx))

	BM.start_battle(armies, scripted_battle.battle_map, 0, null, null, scripted_battle)
	UI.set_camera(E.CameraPosition.BATTLE)


func _clear_players() -> void:
	for player in players:
		player.queue_free()
	players = []

#endregion Game setup


#region Gameplay UI

# MAJOR function that exits gamemodes
func go_to_main_menu():
	if CFG.FULLSCREEN_AUTO_TOGGLE:
		UI.set_fullscreen(false)

	AUDIO.play_music("menu")
	in_map_editor = false
	BM.close_when_quitting_game()
	WM.clear_world()
	UI.go_to_main_menu()

#endregion Gameplay UI


#region Technical
# not gameplay

func is_game_paused():
	return get_tree().paused


func set_game_paused(is_paused : bool):
	print("pause = ",is_paused)
	get_tree().paused = is_paused


func quit_game():
	get_tree().quit()


func get_player_by_index(index : int) -> Player:
	if index in range(players.size()):
		return players[index]
	return null


func get_index_of_player(player : Player) -> int:
	for i in range(players.size()):
		if players[i] == player:
			return i
	return -1


#endregion Technical


#region Information

func get_serializable_world_state() -> SerializableWorldState:
	var state := SerializableWorldState.new()
	if WM.world_game_is_active():
		state = WM.get_serializable_state()
	return state


func get_serializable_battle_state() -> SerializableBattleState:
	var state := SerializableBattleState.new()
	if BM.battle_is_active():
		state.replay = BM.get_ripped_replay()
		if WM.world_game_is_active():
			for army in BM._battle_grid_state.armies_in_battle_state:
				state.world_armies.append(army.army_reference.coord)
			state.combat_coord = WM.combat_tile
	return state


func is_slot_steal_allowed() -> bool:
	if NET.server:
		return true # host always can steal slots
	elif NET.client:
		return NET.client.is_slot_steal_allowed()
	return true # local game

#endregion Information


#region City Defense

func end_city_defense_battle(armies : Array[BattleGridState.ArmyInBattleState]) -> void:
	UI.main_menu.get_node("MainContainer/CityDefense").battle_ended(armies)  # TEMP

#endregion City Defense
